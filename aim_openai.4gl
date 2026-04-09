IMPORT util
IMPORT com

PRIVATE DEFINE _init_counter INTEGER

PUBLIC FUNCTION initialize() RETURNS ()
    LET _init_counter = _init_counter + 1
    IF NOT _check_utf8() THEN
        CALL _disp_warning("UTF-8 encoding is recommended.")
    END IF
END FUNCTION

PRIVATE FUNCTION _check_initialized() RETURNS ()
    CALL _assert((_init_counter>0),"Module was not initialized.")
END FUNCTION

PUBLIC FUNCTION cleanup() RETURNS ()
    CALL _check_initialized()
    LET _init_counter = _init_counter - 1
END FUNCTION

PRIVATE FUNCTION _check_utf8() RETURNS BOOLEAN
    RETURN ( ORD("€") == 8364 )
END FUNCTION

PRIVATE FUNCTION _disp_error(msg STRING) RETURNS ()
    DISPLAY SFMT("OPENAI CLIENT ERROR: %1",msg)
END FUNCTION

PRIVATE FUNCTION _disp_warning(msg STRING) RETURNS ()
    DISPLAY SFMT("OPENAI CLIENT WARNING: %1",msg)
END FUNCTION

PRIVATE FUNCTION _assert(cond BOOLEAN, msg STRING) RETURNS ()
    IF NOT cond THEN
        CALL _disp_error(msg)
        EXIT PROGRAM 1
    END IF
END FUNCTION

PRIVATE DEFINE _err_map DYNAMIC ARRAY OF RECORD
        num INTEGER,
        message STRING
    END RECORD = [
        ( num: -101, message: "No model provided" ),
        ( num: -102, message: "No secret key provided" ),
        ( num: -201, message: "HTTP POST error" ),
        ( num: -202, message: "HTTP POST request error" ),
        ( num: -301, message: "Could not convert text response to JSON object" ),
        ( num: -401, message: "Could not convert JSON to t_response" ),
        ( num: -501, message: "Tool function execution failed" )
    ]

PUBLIC FUNCTION get_error_message(err_num INTEGER) RETURNS STRING
    DEFINE x INTEGER
    LET x = _err_map.search("num", err_num)
    IF x > 0 THEN
        RETURN _err_map[x].message
    ELSE
        RETURN NULL
    END IF
END FUNCTION

PRIVATE FUNCTION _check_client_info(
    client t_client
) RETURNS INTEGER
    IF length(client.request.model)==0 THEN
        RETURN -101
    END IF
    IF length(client.connection.secret_key)==0 THEN
        RETURN -102
    END IF
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _build_server_url(
    client t_client,
    service STRING,
    command STRING
) RETURNS STRING
    DEFINE res STRING
    LET res = SFMT("https://%1/%2/%3",
                   client.connection.base_url, _c_oai_url_version, service)
    IF command IS NOT NULL THEN
        LET res = res, "/", command
    END IF
    RETURN res
END FUNCTION

PRIVATE FUNCTION _create_http_request(
    client t_client,
    method STRING,
    service STRING,
    command STRING
) RETURNS com.HttpRequest
    DEFINE http_req com.HttpRequest
    DEFINE endpoint STRING
    LET endpoint = _build_server_url(client,service,command)
--display "\n *** Request endpoint: ", endpoint
    LET http_req = com.HttpRequest.Create(endpoint)
    CALL http_req.setConnectionTimeOut(client.connection.timeout)
    CALL http_req.setTimeOut(client.request.timeout)
    CALL http_req.setMethod(method) -- POST, DELETE
    CALL http_req.setHeader(_c_http_header_authorization, SFMT("Bearer %1", client.connection.secret_key))
    IF client.connection.organization IS NOT NULL THEN
        CALL http_req.setHeader(_c_http_header_organization, client.connection.organization)
    END IF
    IF client.connection.project IS NOT NULL THEN
        CALL http_req.setHeader(_c_http_header_project, client.connection.project)
    END IF
    RETURN http_req
END FUNCTION

PRIVATE DEFINE _http_post_status INTEGER
PRIVATE DEFINE _http_post_description STRING
PRIVATE DEFINE _http_request_status INTEGER
PRIVATE DEFINE _http_request_errmsg STRING

PUBLIC FUNCTION get_last_http_post_status() RETURNS INTEGER
    RETURN _http_post_status
END FUNCTION

PUBLIC FUNCTION get_last_http_post_description() RETURNS STRING
    RETURN _http_post_description
END FUNCTION

PRIVATE FUNCTION _post_request_command_json_to_string_buffer(
    client t_client,
    service STRING,
    command STRING,
    json_in util.JSONObject
) RETURNS (INTEGER,base.StringBuffer)
    DEFINE http_req com.HttpRequest
    DEFINE http_resp com.HttpResponse
    DEFINE buffer base.StringBuffer
    LET http_req = _create_http_request(client,"POST",service,command)
    CALL http_req.setCharset("UTF-8")
    CALL http_req.setHeader(_c_http_header_content_type,_c_http_header_content_type_json)
    CALL http_req.setHeader(_c_http_header_accept,_c_http_header_content_type_json)
--display "json_in: ", util.JSON.format( json_in.toString() )
    TRY
        CALL http_req.doTextRequest(json_in.toString())
        LET http_resp=http_req.getResponse()
        IF http_resp.getStatusCode() != 200 THEN
           LET _http_post_status = http_resp.getStatusCode()
           LET _http_post_description = http_resp.getStatusDescription()
--display "-201: response body: ",http_resp.getTextResponse()
           RETURN -201, NULL
        ELSE
           LET buffer = base.StringBuffer.create()
           CALL buffer.append(http_resp.getTextResponse())
--display "OK  : response body: ",buffer.toString()
        END IF
    CATCH
        LET _http_request_status = status
        LET _http_request_errmsg = sqlca.sqlerrm
--display "-202: response body: ",http_resp.getTextResponse()
        RETURN -202, NULL
    END TRY
    RETURN 0, buffer
END FUNCTION

PRIVATE FUNCTION _post_request_command_json_to_json(
    client t_client,
    service STRING,
    command STRING,
    json_in util.JSONObject
) RETURNS (INTEGER, util.JSONObject)
    DEFINE s INTEGER
    DEFINE buffer base.StringBuffer
    DEFINE json_out util.JSONObject
    CALL _post_request_command_json_to_string_buffer(client, service, command, json_in)
         RETURNING s, buffer
    IF s<0 THEN RETURN s, NULL END IF
    TRY
        LET json_out = util.JSONObject.parse( buffer.toString() )
    CATCH
        RETURN -301, NULL
    END TRY
    RETURN 0, json_out
END FUNCTION

PRIVATE FUNCTION _do_request_command_json(
    client t_client,
    method STRING, -- DELETE, GET
    service STRING,
    object STRING
) RETURNS (INTEGER,util.JSONObject)
    DEFINE http_req com.HttpRequest
    DEFINE http_resp com.HttpResponse
    DEFINE buffer base.StringBuffer
    DEFINE json_out util.JSONObject
    LET http_req = _create_http_request(client,method,service,object)
    CALL http_req.setCharset("UTF-8")
    CALL http_req.setHeader(_c_http_header_content_type,_c_http_header_content_type_json)
    CALL http_req.setHeader(_c_http_header_accept,_c_http_header_content_type_json)
    TRY
        CALL http_req.doRequest()
        LET http_resp=http_req.getResponse()
        IF http_resp.getStatusCode() != 200 THEN
           LET _http_post_status = http_resp.getStatusCode()
           LET _http_post_description = http_resp.getStatusDescription()
--display "-201: response body: ",http_resp.getTextResponse()
           RETURN -201, NULL
        ELSE
           LET buffer = base.StringBuffer.create()
           CALL buffer.append(http_resp.getTextResponse())
--display "OK  : response body: ",buffer.toString()
        END IF
    CATCH
        LET _http_request_status = status
        LET _http_request_errmsg = sqlca.sqlerrm
--display "-202: response body: ",http_resp.getTextResponse()
        RETURN -202, NULL
    END TRY
    TRY
        LET json_out = util.JSONObject.parse( buffer.toString() )
    CATCH
        RETURN -301, NULL
    END TRY
    RETURN 0, json_out
END FUNCTION

PRIVATE FUNCTION _delete_request_command_json(
    client t_client,
    service STRING,
    object STRING
) RETURNS (INTEGER,util.JSONObject)
    DEFINE s INTEGER
    DEFINE json_out util.JSONObject
    CALL _do_request_command_json(client,"DELETE",service,object)
         RETURNING s, json_out
    RETURN s, json_out
END FUNCTION

PUBLIC FUNCTION (client t_client) set_defaults(
    model STRING
) RETURNS ()
    INITIALIZE client.* TO NULL
    LET client.connection.base_url = "api.openai.com"
    -- Secret key and project id can also be set directly by caller
    LET client.connection.secret_key = fgl_getenv("OPENAI_API_KEY")
    LET client.connection.organization = fgl_getenv("OPENAI_ORGANIZATION_ID")
    LET client.connection.project = fgl_getenv("OPENAI_PROJECT_ID")
    LET client.connection.timeout = 10
    LET client.request.model = model
    LET client.request.timeout = 60
END FUNCTION

PUBLIC TYPE t_client RECORD
        connection RECORD
            base_url STRING,       -- Can be specific
            secret_key STRING,     -- "Authorization: Bearer <secret_key>"
            organization STRING,   -- "OpenAI-Organization: <organization>"
            project STRING,        -- "OpenAI-Project: <project>"
            timeout INTEGER
        END RECORD,
        request RECORD
            model STRING,
            timeout INTEGER
        END RECORD
    END RECORD

PRIVATE CONSTANT _c_http_header_content_type = "Content-Type"
PRIVATE CONSTANT _c_http_header_content_type_json = "application/json"

PRIVATE CONSTANT _c_http_header_accept = "Accept"
PRIVATE CONSTANT _c_http_header_authorization= "Authorization"
PRIVATE CONSTANT _c_http_header_organization = "OpenAI-Organization"
PRIVATE CONSTANT _c_http_header_project = "OpenAI-Project"

-- If this changes, review all TYPE structures!
PRIVATE CONSTANT _c_oai_url_version = "v1"

PRIVATE CONSTANT _c_role_developer = "developer"
PRIVATE CONSTANT _c_role_user      = "user"
PRIVATE CONSTANT _c_role_assistant = "assistant"

PUBLIC CONSTANT c_response_format_json_schema = "json_schema" # Prefered
PUBLIC CONSTANT c_response_format_json_object = "json_object"
PUBLIC TYPE t_response_text_config RECORD
        format RECORD
            type STRING, -- c_response_format_*
            name STRING,
            strict BOOLEAN,
            schema util.JSONObject
        END RECORD
    END RECORD

PUBLIC TYPE t_reasoning RECORD
        effort STRING,
        generate_summary BOOLEAN,
        summary STRING
    END RECORD

PUBLIC TYPE t_input_item RECORD
        role STRING,
        content STRING,
        -- tool results
        type STRING,
        call_id STRING,
        output STRING -- Stringified dictionary
    END RECORD

PUBLIC TYPE t_tool RECORD
       type STRING, -- "function"
       name STRING,
       description STRING,
       parameters RECORD
          type STRING, -- "object"
          properties DICTIONARY OF RECORD
              type STRING,
              description STRING,
              enum DYNAMIC ARRAY OF STRING
          END RECORD,
          required DYNAMIC ARRAY OF STRING
       END RECORD
    END RECORD

PUBLIC TYPE t_response_request RECORD
        model STRING,
        max_output_tokens INTEGER,
        temperature FLOAT,
        top_p FLOAT,
        store BOOLEAN,
        truncation STRING,
        instructions STRING,
        reasoning t_reasoning,
        input DYNAMIC ARRAY OF t_input_item,
        tools DYNAMIC ARRAY OF t_tool,
        previous_response_id STRING,
        text t_response_text_config
    END RECORD

PUBLIC FUNCTION (request t_response_request) set_defaults(
    client t_client
) RETURNS ()
    INITIALIZE request.* TO NULL
    LET request.model = client.request.model
    LET request.temperature = 0.7
    LET request.max_output_tokens = 2048
END FUNCTION

PUBLIC TYPE t_output_item RECORD
        id STRING,
        type STRING,
        status STRING,
        role STRING,
        content DYNAMIC ARRAY OF RECORD
            type STRING,
            text STRING,
            refusal STRING
        END RECORD,
        -- tool calls
        name STRING,
        call_id STRING,
        arguments STRING -- Stringified params
    END RECORD

PUBLIC TYPE t_response RECORD
        type STRING,
        id STRING,
        model STRING,
        object STRING,
        created_at INTEGER,
        status STRING,
        completed_at INTEGER,
        error RECORD
            code STRING,
            message STRING
        END RECORD,
        max_output_tokens INTEGER,
        output DYNAMIC ARRAY OF t_output_item
    END RECORD

PRIVATE FUNCTION _chat_append_input_as_string(
    req t_response_request INOUT,
    role STRING,
    content STRING
) RETURNS INTEGER
    DEFINE x INTEGER
    LET x = req.input.getLength() + 1
    LET req.input[x].role = role
    LET req.input[x].content = content
    RETURN x
END FUNCTION

PUBLIC FUNCTION (req t_response_request) set_instructions(
    content STRING
) RETURNS ()
    LET req.instructions = content
END FUNCTION

PUBLIC FUNCTION (req t_response_request) append_developer_input(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_input_as_string(req, _c_role_developer, content)
END FUNCTION

PUBLIC FUNCTION (req t_response_request) append_user_input(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_input_as_string(req, _c_role_user, content)
END FUNCTION

PUBLIC FUNCTION (req t_response_request) append_assistant_input(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_input_as_string(req, _c_role_assistant, content)
END FUNCTION

PUBLIC TYPE t_tool_signature_params DYNAMIC ARRAY OF RECORD
       name STRING,
       type STRING,
       enum DYNAMIC ARRAY OF STRING,
       description STRING,
       required BOOLEAN
    END RECORD

PUBLIC FUNCTION (req t_response_request) append_tool_definition(
    name STRING,
    description STRING,
    params t_tool_signature_params
) RETURNS INTEGER
    DEFINE x, px, rx INTEGER
    CALL _assert( (length(name)>0),"Tool name is mandatory")
    CALL _assert( (length(description)>0),"Tool description is mandatory")
    CALL req.tools.appendElement()
    LET x = req.tools.getLength()
    LET req.tools[x].type = "function"
    LET req.tools[x].name = name
    LET req.tools[x].description = description
    LET req.tools[x].parameters.type = "object"
    LET rx = 0
    FOR px = 1 TO params.getLength()
        CALL _assert( (length(params[px].name)>0),"Tool param name is mandatory")
        CALL _assert( (length(params[px].type)>0),"Tool param type is mandatory")
        CALL _assert( (length(params[px].description)>0),"Tool param description is mandatory")
        LET req.tools[x].parameters.properties[params[px].name].type = params[px].type
        CALL params[px].enum.copyTo(req.tools[x].parameters.properties[params[px].name].enum)
        LET req.tools[x].parameters.properties[params[px].name].description = params[px].description
        IF params[px].required THEN
           LET req.tools[x].parameters.required[rx:=rx+1] = params[px].name
        END IF
    END FOR
    RETURN x
END FUNCTION

PUBLIC FUNCTION (res t_response) get_output_message_content_text(
    mx INTEGER, -- index of output item of type message
    cx INTEGER -- index of content item in this output item
) RETURNS STRING
    DEFINE ox, nx, x INTEGER
    CALL _assert( (mx>0), SFMT("Invalid message index: %1",x) )
    FOR ox=1 TO res.output.getLength()
        IF res.output[ox].type == "message" THEN
           LET nx = nx+1
           IF nx == mx THEN
              CALL _assert( (cx>0 AND cx<=res.output[ox].content.getLength()),
                             SFMT("Invalid message content index: %1",x) )
              RETURN res.output[ox].content[cx].text
           END IF
        END IF
    END FOR
    RETURN NULL
END FUNCTION

PUBLIC FUNCTION (client t_client) delete_response(
    response t_response INOUT
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE json_out util.JSONObject
    CALL _delete_request_command_json(client,"responses",response.id)
         RETURNING s, json_out
    TRY
       CALL json_out.toFGL(response)
    CATCH
       RETURN -401
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION (client t_client) create_response(
    request t_response_request,
    response t_response INOUT
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject
    INITIALIZE response.* TO NULL
    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
--display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"responses",NULL,json_in)
         RETURNING s, json_out
--display "json_out:\n", util.JSON.format( json_out.toString() )
    IF s<0 THEN RETURN s END IF
    TRY
       CALL json_out.toFGL(response)
    CATCH
       RETURN -401
    END TRY
    IF response.output.getLength()>0 THEN
       IF response.output[1].type=="function_call" THEN
          RETURN 1
       END IF
    END IF
    RETURN 0
END FUNCTION

PUBLIC TYPE t_tool_function_dispatcher FUNCTION (
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER

PUBLIC FUNCTION (client t_client) continue_response(
    request t_response_request,
    response t_response INOUT,
    func_exec t_tool_function_dispatcher
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE x INTEGER
    DEFINE params DICTIONARY OF STRING
    DEFINE results DICTIONARY OF STRING
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject

--display "\nCONTINUING CONVERSATION WITH TOOL CALLS:"

    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF

    CALL _assert(response.type=="response","Expecting response type = response")
    CALL _assert(response.output.search("type","function_call")>0,
                                        "Expecting outputs with type = function_call")

    LET request.previous_response_id = response.id
    CALL request.input.clear()
    CALL request.tools.clear()
    FOR x=1 TO response.output.getLength()
        IF response.output[x].type == "function_call" THEN
           LET request.input[x].type = "function_call_output"
           LET request.input[x].call_id = response.output[x].call_id
           -- Perform tool execution and get results
           CALL util.JSON.parse(response.output[x].arguments,params)
           CALL results.clear()
           LET s = func_exec(response.output[x].name,params,results)
           IF s < 0 THEN
              RETURN -501
           END IF
--display " *** results: ", util.JSON.stringify(results)
           LET request.input[x].output = util.JSON.stringify(results)
        END IF
    END FOR

    INITIALIZE response.* TO NULL
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
--display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"responses",NULL,json_in)
         RETURNING s, json_out
    IF s<0 THEN RETURN s END IF
    TRY
       CALL json_out.toFGL(response)
    CATCH
       RETURN -401
    END TRY
--display "json_out:\n", util.JSON.format( json_out.toString() )

    RETURN 0

END FUNCTION

FUNCTION main()
    DEFINE client t_client
    DEFINE request t_response_request
    DEFINE response t_response
    DEFINE x, tx, s INTEGER

    CALL initialize()

    CALL client.set_defaults("gpt-4o")
    CALL request.set_defaults(client)
    -- Can set API key here instead of using an env var
    -- LET client.connection.secret_key = "xxx"

{
    -- Simple request
    CALL request.set_instructions("You are a Math teacher.")
    LET x = request.append_developer_input("Answer with precise instructions.")
    LET x = request.append_user_input("How to compute the area of a circle?")
    LET s = client.create_response(request,response)
    IF s == 0 THEN
       DISPLAY response.get_output_message_content_text(1,1)
    ELSE
       DISPLAY get_error_message(s)
       DISPLAY "HTTP post status: ", get_last_http_post_status()
       DISPLAY "HTTP post description : ", get_last_http_post_description()
    END IF
    IF response.error.code IS NOT NULL THEN
       DISPLAY "Response error: ", response.error.code, " ", response.error.message
    END IF
    LET s = client.delete_response(response)
    DISPLAY "Delete response result: ", s
}

    -- Request with tools
    CALL request.set_defaults(client)

    VAR mycallback t_tool_function_dispatcher = FUNCTION exec_tools
    CALL request.set_instructions("You are a Math teacher.")
    LET x = request.append_user_input("Use the provided tools to generate the result for a user question.")

    VAR tps1 t_tool_signature_params = [
          (name:"operand_1", type:"number", description:"First operand.", required: TRUE ),
          (name:"operand_2", type:"number", description:"Second operand.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("multiplication","Multiplies two numbers.",tps1)

    VAR tps2 t_tool_signature_params = [
          (name:"dividend", type:"number", description:"The dividend operand.", required: TRUE ),
          (name:"divisor", type:"number", description:"The divisor operand.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("integer_division","Divides two integer numbers and produces a quotient and remainder.",tps2)

    VAR tps3 t_tool_signature_params = [
          (name:"location", type:"string", description:"The name of the place, city or street.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("gcs_coordinates","Returns the geographic coordinate as latitude and longitude of a given place.",tps3)

    --LET x = request.append_user_input("How much is 25 multiplied by 5?")
    --LET x = request.append_user_input("What is the quotient and remainder of 13 divided by 5?")
    LET x = request.append_user_input("What is the exact location of the city of London?")

    LET s = client.create_response(request,response)
    WHILE s == 1 -- tool calls required, we loop until done
        LET s = client.continue_response(request,response,mycallback)
    END WHILE
    IF s == 0 THEN
       DISPLAY response.get_output_message_content_text(1,1)
    ELSE
       DISPLAY get_error_message(s)
       DISPLAY "HTTP post status: ", get_last_http_post_status()
       DISPLAY "HTTP post description : ", get_last_http_post_description()
    END IF
    LET s = client.delete_response(response)
    DISPLAY "Delete response result: ", s

    CALL cleanup()

END FUNCTION

PRIVATE FUNCTION exec_tools(
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER
--display " *** tool call: ", name, " with: ", util.JSON.stringify(params)
    CASE name
    WHEN "multiplication"
       VAR o1 DECIMAL = params["operand_1"]
       VAR o2 DECIMAL = params["operand_2"]
       VAR rs DECIMAL = ( o1 * o2 )
       LET results["result"] = rs
       RETURN 0
    WHEN "integer_division"
       VAR dt INTEGER = params["dividend"]
       VAR dv INTEGER = params["divisor"]
       VAR rs INTEGER = ( dt / dv )
       VAR rm INTEGER = ( dt MOD dv )
       LET results["quotient"] = rs
       LET results["remainder"] = rm
       RETURN 0
    WHEN "gcs_coordinates"
       CASE params["location"]
       WHEN "Paris"    LET results["latitude"]=+48.8566; LET results["longitude"]=+2.3522
       WHEN "London"   LET results["latitude"]=+51.5074; LET results["longitude"]=-0.1278
       WHEN "Madrid"   LET results["latitude"]=+40.4168; LET results["longitude"]=-3.7038
       OTHERWISE RETURN -2
       END CASE
       RETURN 0
    OTHERWISE RETURN -1
    END CASE
END FUNCTION
