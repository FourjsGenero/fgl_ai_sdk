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
    IF client.connection.base_url <> "localhost"
    AND length(client.connection.secret_key)==0 THEN
        RETURN -102
    END IF
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _build_server_url(
    client t_client,
    service STRING
) RETURNS STRING
    DEFINE res STRING
    DEFINE protocol STRING
    LET protocol = IIF(client.connection.base_url=="localhost","http","https")
    LET res = SFMT("%1://%2:%3/api/%4",
                   protocol,
                   client.connection.base_url,
                   client.connection.tcp_port,
                   service)
    RETURN res
END FUNCTION

PRIVATE FUNCTION _post_request_command_create(
    client t_client,
    service STRING
) RETURNS com.HttpRequest
    DEFINE http_req com.HttpRequest
    DEFINE endpoint STRING
    LET endpoint = _build_server_url(client,service)
--display "\n *** Request endpoint: ", endpoint
    LET http_req = com.HttpRequest.Create(endpoint)
    CALL http_req.setConnectionTimeOut(client.connection.timeout)
    CALL http_req.setTimeOut(client.request.timeout)
    CALL http_req.setMethod("POST")
    CALL http_req.setHeader(aim_common.c_http_header_authorization, SFMT("Bearer %1", client.connection.secret_key))
    RETURN http_req
END FUNCTION

PRIVATE FUNCTION _post_request_command_json_to_json(
    client t_client,
    service STRING,
    json_in util.JSONObject
) RETURNS (INTEGER, util.JSONObject)
    DEFINE http_req com.HttpRequest
    DEFINE s INTEGER
    DEFINE json_out util.JSONObject
    LET http_req = _post_request_command_create(client, service)
    CALL aim_common.post_json_to_json(http_req, json_in)
         RETURNING s, json_out
    RETURN s, json_out
END FUNCTION

PUBLIC FUNCTION (client t_client) set_defaults(
    model STRING
) RETURNS ()
    INITIALIZE client.* TO NULL
    LET client.connection.base_url = "localhost"
    LET client.connection.tcp_port = 11434
    -- API Key not needed for local ollama instance
    LET client.connection.timeout = 10
    LET client.request.model = model
    LET client.request.timeout = 60
END FUNCTION

PUBLIC TYPE t_client RECORD
        connection RECORD
            base_url STRING,
            tcp_port INTEGER,
            secret_key STRING,
            timeout INTEGER
        END RECORD,
        request RECORD
            model STRING,
            timeout INTEGER
        END RECORD
    END RECORD

PUBLIC TYPE t_options RECORD
        seed INTEGER,
        temperature FLOAT,
        top_k FLOAT,
        top_p FLOAT,
        min_p FLOAT,
        stop STRING,
        num_ctx INTEGER,
        num_predict INTEGER
    END RECORD

PUBLIC TYPE t_response_request RECORD
        model STRING,
        system STRING,
        prompt STRING,
        stream BOOLEAN,
        think STRING,
        raw BOOLEAN,
        options t_options,
        format util.JSONObject -- JSON schema
    END RECORD

PUBLIC FUNCTION (request t_response_request) set_defaults(
    client t_client
) RETURNS ()
    INITIALIZE request.* TO NULL
    LET request.model = client.request.model
    LET request.options.temperature = 0.7
    LET request.stream = FALSE
END FUNCTION

PUBLIC TYPE t_response RECORD
        model STRING,
        created_at INTEGER,
        response STRING,
        thinking STRING,
        done BOOLEAN,
        done_reason STRING,
        total_duration INTEGER,
        load_duration INTEGER,
        prompt_eval_count INTEGER,
        prompt_eval_duration INTEGER,
        eval_count INTEGER,
        eval_duration INTEGER
    END RECORD

PUBLIC FUNCTION (req t_response_request) set_system_message(
    content STRING
) RETURNS ()
    LET req.system = content
END FUNCTION

PUBLIC FUNCTION (req t_response_request) set_prompt_message(
    content STRING
) RETURNS ()
    LET req.prompt = content
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
    CALL _post_request_command_json_to_json(client,"generate",json_in)
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

