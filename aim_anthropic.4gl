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
    CALL http_req.setHeader(_c_http_header_x_api_key, client.connection.secret_key)
    CALL http_req.setHeader(_c_http_header_anthropic_version, _c_oai_anthropic_version)
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
    LET http_req = _post_request_command_create(client, service, command)
    CALL aim_common.post_json_to_json(http_req, json_in)
         RETURNING s, json_out
    RETURN s, json_out
END FUNCTION

PUBLIC FUNCTION (client t_client) set_defaults(
    model STRING
) RETURNS ()
    INITIALIZE client.* TO NULL
    LET client.connection.base_url = "api.anthropic.com"
    -- Secret key and project id can also be set directly by caller
    LET client.connection.secret_key = aim_common.get_api_key("anthropic", "ANTHROPIC_API_KEY")
    LET client.connection.timeout = 10
    LET client.request.model = model
    LET client.request.timeout = 60
END FUNCTION

PUBLIC TYPE t_client RECORD
        connection RECORD
            base_url STRING,
            secret_key STRING,
            timeout INTEGER
        END RECORD,
        request RECORD
            model STRING,
            timeout INTEGER
        END RECORD
    END RECORD

PRIVATE CONSTANT _c_http_header_x_api_key = "x-api-key"
PRIVATE CONSTANT _c_http_header_anthropic_version = "anthropic-version"

-- If this changes, review all TYPE structures!
PRIVATE CONSTANT _c_oai_url_version = "v1"
-- Anthropic only: If this changes, review all TYPE structures!
PRIVATE CONSTANT _c_oai_anthropic_version = "2023-06-01"

PRIVATE CONSTANT _c_role_user      = "user"
PRIVATE CONSTANT _c_role_assistant = "assistant"

PUBLIC CONSTANT c_response_format_json_schema = "json_schema"
PUBLIC TYPE t_output_config RECORD
        effort STRING,
        format RECORD
            type STRING, -- "json_schema"
            schema util.JSONObject
        END RECORD
    END RECORD

PUBLIC TYPE t_tool RECORD
       name STRING,
       description STRING,
       input_schema util.JSONObject
    END RECORD

PUBLIC TYPE t_message_request RECORD
        model STRING,
        max_tokens INTEGER,
        speed STRING,
        system STRING,
        messages util.JSONArray,
        tools DYNAMIC ARRAY OF t_tool,
        output_config t_output_config
    END RECORD

PUBLIC FUNCTION (request t_message_request) set_defaults(
    client t_client
) RETURNS ()
    INITIALIZE request.* TO NULL
    LET request.model = client.request.model
    LET request.messages = util.JSONArray.create()
    LET request.max_tokens = 2048
END FUNCTION

-- TODO? Convert to util.JSONObject ?
PUBLIC TYPE t_response_content RECORD
        type STRING,
        -- For type=text
        text STRING,
        -- For type=tool_use
        id STRING,
        name STRING,
        input util.JSONObject
    END RECORD

PUBLIC TYPE t_usage RECORD
        input_tokens INTEGER,
        cache_creation_input_tokens INTEGER,
        cache_read_input_tokens INTEGER,
        output_tokens INTEGER
    END RECORD

PUBLIC TYPE t_response RECORD
        id STRING,
        model STRING,
        type STRING,
        role STRING,
        content DYNAMIC ARRAY OF t_response_content,
        stop_reason STRING,
        stop_sequence STRING,
        usage t_usage
    END RECORD

PRIVATE FUNCTION _chat_append_message_as_string(
    req t_message_request INOUT,
    role STRING,
    content STRING
) RETURNS INTEGER
    DEFINE x INTEGER
    DEFINE jo util.JSONObject
    LET jo = util.JSONObject.create()
    CALL jo.put("role",role)
    CALL jo.put("content",content)
    LET x = req.messages.getLength() + 1
    CALL req.messages.put(x,jo)
    RETURN x
END FUNCTION

PRIVATE FUNCTION _chat_append_message_content_as_array(
    req t_message_request INOUT,
    role STRING
) RETURNS INTEGER
    DEFINE x INTEGER
    DEFINE jo util.JSONObject
    LET jo = util.JSONObject.create()
    CALL jo.put("role",role)
    CALL jo.put("content",util.JSONArray.create())
    LET x = req.messages.getLength() + 1
    CALL req.messages.put(x,jo)
--display "messages: ", util.JSON.format( req.messages.toString() )
    RETURN x
END FUNCTION

PRIVATE FUNCTION _chat_append_message_content_element(
    req t_message_request INOUT,
    mx INTEGER,
    element util.JSONObject
) RETURNS INTEGER
    DEFINE x INTEGER
    DEFINE jo util.JSONObject
    DEFINE ja util.JSONArray
    LET jo = req.messages.get(mx)
    LET ja = jo.get("content")
    LET x = ja.getLength() + 1
    CALL ja.put(x,element)
--display "messages: ", util.JSON.format( req.messages.toString() )
    RETURN x
END FUNCTION

PUBLIC FUNCTION (req t_message_request) append_message_element_object(
    mx INTEGER,
    jo_element util.JSONObject
) RETURNS INTEGER
    RETURN _chat_append_message_content_element(req,mx,jo_element)
END FUNCTION

PUBLIC FUNCTION (req t_message_request) append_message_element_text(
    mx INTEGER,
    text STRING
) RETURNS INTEGER
    DEFINE jo_element util.JSONObject
    LET jo_element = util.JSONObject.create()
    CALL jo_element.put("type","text")
    CALL jo_element.put("text",text)
    RETURN _chat_append_message_content_element(req,mx,jo_element)
END FUNCTION

PRIVATE FUNCTION _create_tool_result_json_object(
    tool_use_id STRING
) RETURNS util.JSONObject
    DEFINE jo_element util.JSONObject
    LET jo_element = util.JSONObject.create()
    CALL jo_element.put("type","tool_result")
    CALL jo_element.put("tool_use_id",tool_use_id)
    RETURN jo_element
END FUNCTION

PRIVATE FUNCTION _append_message_element_tool_result(
    req t_message_request INOUT,
    mx INTEGER,
    tool_use_id STRING,
    values DICTIONARY OF STRING
) RETURNS INTEGER
    DEFINE jo_element util.JSONObject
    LET jo_element = _create_tool_result_json_object(tool_use_id)
    IF values.getLength()==1 THEN
        VAR keys DYNAMIC ARRAY OF STRING = values.getKeys()
        CALL jo_element.put("content",values[keys[1]])
    ELSE
        VAR x INTEGER
        VAR keys DYNAMIC ARRAY OF STRING
        VAR vs DYNAMIC ARRAY OF RECORD
               type STRING,
               text STRING
            END RECORD
        LET keys = values.getKeys()
        FOR x=1 TO keys.getLength()
            LET vs[x].type = "text"
            LET vs[x].text = values[keys[x]]
        END FOR
        CALL jo_element.put("content",util.JSONArray.fromFGL(vs))
    END IF
    RETURN _chat_append_message_content_element(req,mx,jo_element)
END FUNCTION

PUBLIC FUNCTION (req t_message_request) set_system_message(
    content STRING
) RETURNS ()
    LET req.system = content
END FUNCTION

PUBLIC FUNCTION (req t_message_request) append_user_message(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_message_as_string(req, _c_role_user, content)
END FUNCTION

PUBLIC FUNCTION (req t_message_request) append_assistant_message(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_message_as_string(req, _c_role_assistant, content)
END FUNCTION

PUBLIC FUNCTION (req t_message_request) append_user_message_as_array() RETURNS INTEGER
    RETURN _chat_append_message_content_as_array(req,_c_role_user)
END FUNCTION

PUBLIC FUNCTION (req t_message_request) append_assistant_message_as_array() RETURNS INTEGER
    RETURN _chat_append_message_content_as_array(req,_c_role_assistant)
END FUNCTION

PUBLIC FUNCTION (req t_message_request) append_tool_definition(
    name STRING,
    description STRING,
    params aim_common.t_tool_signature_params
) RETURNS INTEGER
    DEFINE x, px INTEGER
    DEFINE properties util.JSONObject
    DEFINE tool_param util.JSONObject
    DEFINE required util.JSONArray
    CALL aim_common.assert( (length(name)>0),"Tool name is mandatory")
    CALL aim_common.assert( (length(description)>0),"Tool description is mandatory")
    CALL req.tools.appendElement()
    LET x = req.tools.getLength()
    LET req.tools[x].name = name
    LET req.tools[x].description = description
    LET req.tools[x].input_schema = util.JSONObject.create()
    CALL req.tools[x].input_schema.put("type","object")
    LET properties = util.JSONObject.create()
    LET required = util.JSONArray.create()
    FOR px = 1 TO params.getLength()
        CALL aim_common.assert( (length(params[px].name)>0),"Tool param name is mandatory")
        CALL aim_common.assert( (length(params[px].type)>0),"Tool param type is mandatory")
        CALL aim_common.assert( (length(params[px].description)>0),"Tool param description is mandatory")
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
    CALL req.tools[x].input_schema.put("properties",properties)
    CALL req.tools[x].input_schema.put("required",required)
    RETURN x
END FUNCTION

PUBLIC FUNCTION (res t_response) get_content_text(
    x INTEGER
) RETURNS STRING
    CALL aim_common.assert( (x>0), SFMT("Invalid index: %1",x) )
    IF x>0 AND x <= res.content.getLength() THEN
        RETURN res.content[x].text
    END IF
    RETURN NULL
END FUNCTION

PUBLIC FUNCTION (client t_client) create_message(
    request t_message_request,
    response t_response INOUT
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
    CALL _post_request_command_json_to_json(client,"messages",NULL,json_in)
         RETURNING s, json_out
    IF s<0 THEN RETURN s END IF
    TRY
       CALL json_out.toFGL(response)
    CATCH
       RETURN -401
    END TRY
--display "json_out:\n", util.JSON.format( json_out.toString() )
    IF response.stop_reason=="tool_use" THEN
       RETURN 1
    END IF
    RETURN 0
END FUNCTION

PUBLIC FUNCTION (client t_client) continue_message(
    request t_message_request,
    response t_response INOUT,
    func_exec aim_common.t_tool_function_dispatcher
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE x, mx, ex, rmx, px INTEGER
    DEFINE jo_tool util.JSONObject
    DEFINE jo_input util.JSONObject
    DEFINE tool_use_id STRING
    DEFINE params DICTIONARY OF STRING
    DEFINE results DICTIONARY OF STRING
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject

--display "\nCONTINUING CONVERSATION WITH TOOL CALLS:"

    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF

    CALL aim_common.assert(response.stop_reason=="tool_use","Expecting stop_reason = tool_use")

    LET mx = request.append_assistant_message_as_array()
    FOR x=1 TO response.content.getLength()
        CASE
        WHEN response.content[x].type == "text"
          LET ex = request.append_message_element_text(mx,response.content[x].text)
        WHEN response.content[x].type == "tool_use"
          LET jo_tool = util.JSONObject.create()
          CALL jo_tool.put("type",response.content[x].type)
          CALL jo_tool.put("id",response.content[x].id)
          CALL jo_tool.put("name",response.content[x].name)
          CALL jo_tool.put("input",response.content[x].input)
          LET tool_use_id = jo_tool.get("id")
          LET ex = request.append_message_element_object(mx,jo_tool)
          -- Perform tool execution
          IF rmx==0 THEN
             LET rmx = request.append_user_message_as_array()
          END IF
          CALL params.clear()
--display " *** jo_tool: ", jo_tool.toString()
          IF jo_tool.has("input") THEN
             LET jo_input = jo_tool.get("input")
             FOR px=1 TO jo_input.getLength()
                LET params[jo_input.name(px)] = jo_input.get(jo_input.name(px))
             END FOR
          END IF
          CALL results.clear()
          LET s = func_exec(jo_tool.get("name"),params,results)
          IF s < 0 THEN
             RETURN -501
          END IF
--display " *** results: ", util.JSON.stringify(results)
          LET ex = _append_message_element_tool_result(request,rmx,tool_use_id,results)
        END CASE
    END FOR

    INITIALIZE response.* TO NULL
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
--display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"messages",NULL,json_in)
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

