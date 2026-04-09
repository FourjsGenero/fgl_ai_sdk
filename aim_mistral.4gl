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
    DISPLAY SFMT("MISTRAL CLIENT ERROR: %1",msg)
END FUNCTION

PRIVATE FUNCTION _disp_warning(msg STRING) RETURNS ()
    DISPLAY SFMT("MISTRAL CLIENT WARNING: %1",msg)
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
        ( num: -501, message: "Tool function execution failed" ),
        ( num: -502, message: "Failed to parse tool call arguments" )
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

PRIVATE FUNCTION _post_request_command_create(
    client t_client,
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
    CALL http_req.setMethod("POST")
    CALL http_req.setHeader(_c_http_header_authorization, SFMT("Bearer %1", client.connection.secret_key))
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
    LET http_req = _post_request_command_create(client,service,command)
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

PUBLIC FUNCTION (client t_client) set_defaults(
    model STRING
) RETURNS ()
    INITIALIZE client.* TO NULL
    IF model MATCHES "codestral*" THEN
       LET client.connection.base_url = "codestral.mistral.ai"
    ELSE
       LET client.connection.base_url = "api.mistral.ai"
    END IF
    -- Secret key and project id can also be set directly by caller
    LET client.connection.secret_key = fgl_getenv("MISTRAL_API_KEY")
    LET client.connection.timeout = 10
    LET client.request.model = model
    LET client.request.timeout = 60
END FUNCTION

PUBLIC TYPE t_client RECORD
        connection RECORD
            base_url STRING,       -- Can be specific (codestral.mistral.ai)
            secret_key STRING,     -- "Authorization: Bearer <secret_key>"
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

-- If this changes, review all TYPE structures!
PRIVATE CONSTANT _c_oai_url_version = "v1"

PRIVATE CONSTANT _c_role_system    = "system"
PRIVATE CONSTANT _c_role_user      = "user"
PRIVATE CONSTANT _c_role_assistant = "assistant"
PRIVATE CONSTANT _c_role_tool      = "tool"

PUBLIC TYPE t_tool_call RECORD
        id STRING,
        type STRING, -- "function"
        function RECORD
            name STRING,
            arguments STRING -- Stringified ditionary
        END RECORD
    END RECORD

PUBLIC TYPE t_chat_request_message RECORD
        role STRING,
        content STRING,
        -- tool calls and results
        tool_calls DYNAMIC ARRAY OF t_tool_call,
        tool_call_id STRING,
        name STRING
    END RECORD

PUBLIC CONSTANT c_response_format_json_schema = "json_schema" # Prefered
PUBLIC CONSTANT c_response_format_json_object = "json_object"
PUBLIC TYPE t_response_format RECORD
        type STRING, -- c_response_format_*
        json_schema util.JSONObject
    END RECORD

PUBLIC TYPE t_tool RECORD
       type STRING, -- "function"
       function RECORD
           name STRING,
           description STRING,
           strict BOOLEAN,
           parameters util.JSONObject
       END RECORD
    END RECORD

PUBLIC TYPE t_chat_request RECORD
        model STRING,
        max_tokens INTEGER,
        temperature FLOAT,
        top_p FLOAT,
        frequency_penalty FLOAT,
        presence_penalty FLOAT,
        prompt_mode STRING,
        random_seed INTEGER,
        n INTEGER, -- number of choices in response
        messages DYNAMIC ARRAY OF t_chat_request_message,
        tools DYNAMIC ARRAY OF t_tool,
        response_format t_response_format
    END RECORD

PUBLIC FUNCTION (request t_chat_request) set_defaults(
    client t_client
) RETURNS ()
    INITIALIZE request.* TO NULL
    LET request.model = client.request.model
    LET request.temperature = 0.7
    LET request.max_tokens = 2048
END FUNCTION

PUBLIC TYPE t_chat_response_message RECORD
        role STRING,
        content STRING,
        prefix BOOLEAN,
        tool_calls DYNAMIC ARRAY OF t_tool_call
    END RECORD

PUBLIC TYPE t_chat_choice RECORD
        index INTEGER,
        finish_reason STRING,
        message t_chat_response_message
    END RECORD

PUBLIC TYPE t_usage RECORD
        completion_tokens INTEGER,
        prompt_tokens INTEGER,
        total_tokens INTEGER
    END RECORD

PUBLIC TYPE t_chat_response RECORD
        id STRING,
        model STRING,
        usage t_usage,
        choices DYNAMIC ARRAY OF t_chat_choice,
        created INTEGER,
        system_fingerprint STRING,
        object STRING
    END RECORD

PRIVATE FUNCTION _chat_append_message_as_string(
    req t_chat_request INOUT,
    role STRING,
    content STRING
) RETURNS INTEGER
    DEFINE x INTEGER
    CALL req.messages.appendElement()
    LET x = req.messages.getLength()
    LET req.messages[x].role = role
    LET req.messages[x].content = content
    RETURN x
END FUNCTION

PUBLIC FUNCTION (req t_chat_request) set_system_message(
    content STRING
) RETURNS ()
    DEFINE x INTEGER
    CALL req.messages.clear()
    LET x = _chat_append_message_as_string(req, _c_role_system, content)
END FUNCTION

PUBLIC FUNCTION (req t_chat_request) append_user_message(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_message_as_string(req, _c_role_user, content)
END FUNCTION

PUBLIC FUNCTION (req t_chat_request) append_assistant_message(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_message_as_string(req, _c_role_assistant, content)
END FUNCTION

PUBLIC TYPE t_tool_signature_params DYNAMIC ARRAY OF RECORD
       name STRING,
       type STRING,
       enum DYNAMIC ARRAY OF STRING,
       description STRING,
       required BOOLEAN
    END RECORD

PUBLIC FUNCTION (req t_chat_request) append_tool_definition(
    name STRING,
    description STRING,
    params t_tool_signature_params
) RETURNS INTEGER
    DEFINE x, px INTEGER
    DEFINE properties util.JSONObject
    DEFINE tool_param util.JSONObject
    DEFINE required util.JSONArray
    CALL _assert( (length(name)>0),"Tool name is mandatory")
    CALL _assert( (length(description)>0),"Tool description is mandatory")
    CALL req.tools.appendElement()
    LET x = req.tools.getLength()
    LET req.tools[x].type = "function"
    LET req.tools[x].function.name = name
    LET req.tools[x].function.description = description
    LET req.tools[x].function.parameters = util.JSONObject.create()
    CALL req.tools[x].function.parameters.put("type","object")
    LET properties = util.JSONObject.create()
    LET required = util.JSONArray.create()
    FOR px = 1 TO params.getLength()
        CALL _assert( (length(params[px].name)>0),"Tool param name is mandatory")
        CALL _assert( (length(params[px].type)>0),"Tool param type is mandatory")
        CALL _assert( (length(params[px].description)>0),"Tool param description is mandatory")
        LET tool_param = util.JSONObject.create()
        CALL tool_param.put("type",params[px].type)
        IF params[px].enum.getLength()>0 THEN
           CALL tool_param.put("enum",util.JSONArray.fromFGL(params[px].enum))
        END IF
        CALL tool_param.put("description",params[px].description)
        CALL properties.put(params[px].name,tool_param)
        IF params[px].required THEN
           CALL required.put(required.getLength()+1,params[px].name)
        END IF
    END FOR
    CALL req.tools[x].function.parameters.put("properties",properties)
    CALL req.tools[x].function.parameters.put("required",required)
    RETURN x
END FUNCTION

PRIVATE FUNCTION _append_message_element_tool_result(
    req t_chat_request INOUT,
    tool_call_id STRING,
    tool_name STRING,
    values DICTIONARY OF STRING
) RETURNS INTEGER
    DEFINE mx INTEGER
    -- Mistral gets tool results in the "content" property of a "tool" message,
    -- as a JSON stringified dictionary:
    --   "content": "{\"temperature\": 32, \"conditions\": \"sunny\"}"
    LET mx = _chat_append_message_as_string(req, _c_role_tool,
                                            util.JSON.stringify(values))
    LET req.messages[mx].tool_call_id = tool_call_id
    LET req.messages[mx].name = tool_name
    RETURN mx
END FUNCTION

PUBLIC FUNCTION (res t_chat_response) get_content_text(
    x INTEGER
) RETURNS STRING
    CALL _assert( (x>0), SFMT("Invalid choice index: %1",x) )
    IF x>0 AND x<=res.choices.getLength() THEN
        RETURN res.choices[x].message.content
    END IF
    RETURN NULL
END FUNCTION

PUBLIC FUNCTION (client t_client) create_chat_completion(
    request t_chat_request,
    response t_chat_response INOUT
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject
    INITIALIZE response.* TO NULL
--display "\nSTART OF CONVERSATION:"
    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
--display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"chat","completions",json_in)
         RETURNING s, json_out
--display "json_out:\n", util.JSON.format( json_out.toString() )
    IF s<0 THEN RETURN s END IF
    TRY
       CALL json_out.toFGL(response)
    CATCH
       RETURN -401
    END TRY
    IF response.choices.getLength()>0 THEN
       IF response.choices[1].finish_reason=="tool_calls" THEN
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

PUBLIC FUNCTION (client t_client) continue_chat_completion(
    request t_chat_request,
    response t_chat_response INOUT,
    func_exec t_tool_function_dispatcher
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE x, mx INTEGER
    DEFINE tool_call_id STRING
    DEFINE tool_name STRING
    DEFINE params DICTIONARY OF STRING
    DEFINE results DICTIONARY OF STRING
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject

--display "\nCONTINUING CONVERSATION WITH TOOL CALLS:"

    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF

    CALL _assert(response.choices.getLength()==1,"Expecting one choice only")
    CALL _assert(response.choices[1].finish_reason=="tool_calls","Expecting tool call finish reason")

    LET mx = request.append_assistant_message(NULL)
    FOR x=1 TO response.choices[1].message.tool_calls.getLength()
        LET tool_call_id = response.choices[1].message.tool_calls[x].id
        LET request.messages[mx].tool_calls[x].id = tool_call_id
        LET request.messages[mx].tool_calls[x].type = "function"
        LET tool_name = response.choices[1].message.tool_calls[x].function.name
        LET request.messages[mx].tool_calls[x].function.name = tool_name
        LET request.messages[mx].tool_calls[x].function.arguments =
               response.choices[1].message.tool_calls[x].function.arguments
        -- Perform tool execution
        TRY
           CALL util.JSON.parse(response.choices[1].message.tool_calls[x].function.arguments,
                                params)
        CATCH
           RETURN -502
        END TRY
--display " *** params : ", util.JSON.stringify(params)
        CALL results.clear()
        LET s = func_exec(tool_name,params,results)
        IF s < 0 THEN
           RETURN -501
        END IF
--display " *** results: ", util.JSON.stringify(results)
        LET mx = _append_message_element_tool_result(request,tool_call_id,tool_name,results)
    END FOR

    INITIALIZE response.* TO NULL
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
--display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"chat","completions",json_in)
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
    DEFINE request t_chat_request
    DEFINE response t_chat_response
    DEFINE x, tx, s INTEGER

    CALL initialize()

    CALL client.set_defaults("mistral-large-latest")
    -- Can set API key here instead of using an env var
    -- LET client.connection.secret_key = "xxx"

{
    -- Simple request
    CALL request.set_defaults(client)
    CALL request.set_system_message("You are a Math teacher.")
    LET x = request.append_user_message("Answer with precise instructions.")
    LET x = request.append_user_message("How to compute the area of a circle?")
    LET s = client.create_chat_completion(request,response)
    IF s == 0 THEN
       DISPLAY response.get_content_text(1)
    ELSE
       DISPLAY get_error_message(s)
       DISPLAY "HTTP post status: ", get_last_http_post_status()
       DISPLAY "HTTP post description : ", get_last_http_post_description()
    END IF
}

    -- Request with tools
    CALL request.set_defaults(client)

    VAR mycallback t_tool_function_dispatcher = FUNCTION exec_tools
    CALL request.set_system_message("You are a Math teacher.")
    LET x = request.append_user_message("Use the provided tools to generate the result for a user question.")

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

    LET x = request.append_user_message("How much is 25 multiplied by 5?")
    --LET x = request.append_user_message("What is the quotient and remainder of 13 divided by 5?")
    --LET x = request.append_user_message("What is the exact location of the city of London?")

    LET s = client.create_chat_completion(request,response)
    WHILE s == 1 -- tool calls required, we loop until done
        LET s = client.continue_chat_completion(request,response,mycallback)
    END WHILE
    IF s == 0 THEN
       DISPLAY response.get_content_text(1)
    ELSE
       DISPLAY get_error_message(s)
       DISPLAY "HTTP post status: ", get_last_http_post_status()
       DISPLAY "HTTP post description : ", get_last_http_post_description()
    END IF

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
