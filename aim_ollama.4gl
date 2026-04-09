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
    DISPLAY SFMT("OLLAMA CLIENT ERROR: %1",msg)
END FUNCTION

PRIVATE FUNCTION _disp_warning(msg STRING) RETURNS ()
    DISPLAY SFMT("OLLAMA CLIENT WARNING: %1",msg)
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
        ( num: -401, message: "Could not convert JSON to t_response" )
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
    json_in util.JSONObject
) RETURNS (INTEGER,base.StringBuffer)
    DEFINE http_req com.HttpRequest
    DEFINE http_resp com.HttpResponse
    DEFINE buffer base.StringBuffer
    LET http_req = _post_request_command_create(client,service)
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
    json_in util.JSONObject
) RETURNS (INTEGER, util.JSONObject)
    DEFINE s INTEGER
    DEFINE buffer base.StringBuffer
    DEFINE json_out util.JSONObject
    CALL _post_request_command_json_to_string_buffer(client,service,json_in)
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

PRIVATE CONSTANT _c_http_header_content_type = "Content-Type"
PRIVATE CONSTANT _c_http_header_content_type_json = "application/json"

PRIVATE CONSTANT _c_http_header_accept = "Accept"
PRIVATE CONSTANT _c_http_header_authorization= "Authorization"

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

FUNCTION main()
    DEFINE client t_client
    DEFINE request t_response_request
    DEFINE response t_response
    DEFINE s INTEGER
    CALL initialize()
    CALL client.set_defaults("llama3.1")
    -- No API key required...
    CALL request.set_defaults(client)
    CALL request.set_system_message("You are a Math teacher.\n Answer with precise instructions.")
    CALL request.set_prompt_message("How to compute the area of a circle?")
    LET s = client.create_response(request,response)
    IF s == 0 THEN
       DISPLAY response.response
    ELSE
       DISPLAY get_error_message(s)
       DISPLAY "HTTP post status: ", get_last_http_post_status()
       DISPLAY "HTTP post description : ", get_last_http_post_description()
    END IF
    CALL cleanup()
END FUNCTION
