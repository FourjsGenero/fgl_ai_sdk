PACKAGE com.fourjs.aim

IMPORT util
IMPORT com
IMPORT FGL com.fourjs.aim.aim_common

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
    CALL http_req.setHeader(aim_common.c_http_header_authorization, SFMT("Bearer %1", client.connection.secret_key))
    IF client.connection.organization IS NOT NULL THEN
        CALL http_req.setHeader(_c_http_header_organization, client.connection.organization)
    END IF
    IF client.connection.project IS NOT NULL THEN
        CALL http_req.setHeader(_c_http_header_project, client.connection.project)
    END IF
    RETURN http_req
END FUNCTION

PRIVATE FUNCTION _post_request_command_json_to_json(
    client t_client,
    service STRING,
    command STRING,
    json_in util.JSONObject
) RETURNS (INTEGER, util.JSONObject)
    DEFINE http_req com.HttpRequest
    DEFINE s INTEGER
    DEFINE json_out util.JSONObject
    LET http_req = _create_http_request(client, "POST", service, command)
    CALL aim_common.post_json_to_json(http_req, json_in)
         RETURNING s, json_out
    RETURN s, json_out
END FUNCTION

PRIVATE FUNCTION _delete_request_command_json(
    client t_client,
    service STRING,
    object STRING
) RETURNS (INTEGER, util.JSONObject)
    DEFINE http_req com.HttpRequest
    DEFINE s INTEGER
    DEFINE json_out util.JSONObject
    LET http_req = _create_http_request(client, "DELETE", service, object)
    CALL aim_common.do_request_to_json(http_req)
         RETURNING s, json_out
    RETURN s, json_out
END FUNCTION

PUBLIC FUNCTION (client t_client) set_defaults(
    model STRING
) RETURNS ()
    INITIALIZE client.* TO NULL
    LET client.connection.base_url = "api.openai.com"
    -- Secret key and project id can also be set directly by caller
    LET client.connection.secret_key = aim_common.get_api_key("openai", "OPENAI_API_KEY")
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

PUBLIC FUNCTION (req t_response_request) append_tool_definition(
    name STRING,
    description STRING,
    params aim_common.t_tool_signature_params
) RETURNS INTEGER
    DEFINE x, px, rx INTEGER
    CALL aim_common.assert( (length(name)>0),"Tool name is mandatory")
    CALL aim_common.assert( (length(description)>0),"Tool description is mandatory")
    CALL req.tools.appendElement()
    LET x = req.tools.getLength()
    LET req.tools[x].type = "function"
    LET req.tools[x].name = name
    LET req.tools[x].description = description
    LET req.tools[x].parameters.type = "object"
    LET rx = 0
    FOR px = 1 TO params.getLength()
        CALL aim_common.assert( (length(params[px].name)>0),"Tool param name is mandatory")
        CALL aim_common.assert( (length(params[px].type)>0),"Tool param type is mandatory")
        CALL aim_common.assert( (length(params[px].description)>0),"Tool param description is mandatory")
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
    CALL aim_common.assert( (mx>0), SFMT("Invalid message index: %1",x) )
    FOR ox=1 TO res.output.getLength()
        IF res.output[ox].type == "message" THEN
           LET nx = nx+1
           IF nx == mx THEN
              CALL aim_common.assert( (cx>0 AND cx<=res.output[ox].content.getLength()),
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

PUBLIC FUNCTION (client t_client) continue_response(
    request t_response_request,
    response t_response INOUT,
    func_exec aim_common.t_tool_function_dispatcher
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

    CALL aim_common.assert(response.type=="response","Expecting response type = response")
    CALL aim_common.assert(response.output.search("type","function_call")>0,
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
