PACKAGE com.fourjs.aim

IMPORT util
IMPORT com

-- Lifecycle

PRIVATE DEFINE _init_counter INTEGER

PUBLIC FUNCTION initialize() RETURNS ()
    LET _init_counter = _init_counter + 1
    IF NOT check_utf8() THEN
        CALL disp_warning("AIM SDK", "UTF-8 encoding is recommended.")
    END IF
END FUNCTION

PUBLIC FUNCTION cleanup() RETURNS ()
    CALL assert((_init_counter>0),"Module was not initialized.")
    LET _init_counter = _init_counter - 1
END FUNCTION

-- Utility

PUBLIC FUNCTION check_utf8() RETURNS BOOLEAN
    RETURN ( ORD("€") == 8364 )
END FUNCTION

PUBLIC FUNCTION disp_error(prefix STRING, msg STRING) RETURNS ()
    DISPLAY SFMT("%1 ERROR: %2", prefix, msg)
END FUNCTION

PUBLIC FUNCTION disp_warning(prefix STRING, msg STRING) RETURNS ()
    DISPLAY SFMT("%1 WARNING: %2", prefix, msg)
END FUNCTION

PUBLIC FUNCTION get_api_key(provider STRING, env_var STRING) RETURNS STRING
    DEFINE val STRING
    LET val = fgl_getresource(SFMT("aim.apikey.%1", provider))
    IF val IS NULL THEN
        LET val = fgl_getenv(env_var)
    END IF
    RETURN val
END FUNCTION

PUBLIC FUNCTION assert(cond BOOLEAN, msg STRING) RETURNS ()
    IF NOT cond THEN
        CALL disp_error("AIM SDK", msg)
        EXIT PROGRAM 1
    END IF
END FUNCTION

-- Error map (union of all provider error codes)

PRIVATE DEFINE _err_map DYNAMIC ARRAY OF RECORD
        num INTEGER,
        message STRING
    END RECORD = [
        ( num: -101, message: "No model provided" ),
        ( num: -102, message: "No secret key provided" ),
        ( num: -103, message: "No project id provided" ),
        ( num: -201, message: "HTTP POST error" ),
        ( num: -202, message: "HTTP POST request error" ),
        ( num: -301, message: "Could not convert text response to JSON object" ),
        ( num: -401, message: "Could not convert JSON response to FGL type" ),
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

-- HTTP infrastructure

PUBLIC CONSTANT c_http_header_content_type = "Content-Type"
PUBLIC CONSTANT c_http_header_content_type_json = "application/json"
PUBLIC CONSTANT c_http_header_accept = "Accept"
PUBLIC CONSTANT c_http_header_authorization = "Authorization"

PRIVATE DEFINE _http_post_status INTEGER
PRIVATE DEFINE _http_post_description STRING

PUBLIC FUNCTION get_last_http_post_status() RETURNS INTEGER
    RETURN _http_post_status
END FUNCTION

PUBLIC FUNCTION get_last_http_post_description() RETURNS STRING
    RETURN _http_post_description
END FUNCTION

PUBLIC FUNCTION post_json_request(
    http_req com.HttpRequest,
    json_in util.JSONObject
) RETURNS (INTEGER, base.StringBuffer)
    DEFINE http_resp com.HttpResponse
    DEFINE buffer base.StringBuffer
    CALL http_req.setCharset("UTF-8")
    CALL http_req.setHeader(c_http_header_content_type, c_http_header_content_type_json)
    CALL http_req.setHeader(c_http_header_accept, c_http_header_content_type_json)
    TRY
        CALL http_req.doTextRequest(json_in.toString())
        LET http_resp = http_req.getResponse()
        IF http_resp.getStatusCode() != 200 THEN
            LET _http_post_status = http_resp.getStatusCode()
            LET _http_post_description = http_resp.getStatusDescription()
            RETURN -201, NULL
        ELSE
            LET buffer = base.StringBuffer.create()
            CALL buffer.append(http_resp.getTextResponse())
        END IF
    CATCH
        RETURN -202, NULL
    END TRY
    RETURN 0, buffer
END FUNCTION

PUBLIC FUNCTION post_json_to_json(
    http_req com.HttpRequest,
    json_in util.JSONObject
) RETURNS (INTEGER, util.JSONObject)
    DEFINE s INTEGER
    DEFINE buffer base.StringBuffer
    DEFINE json_out util.JSONObject
    CALL post_json_request(http_req, json_in)
         RETURNING s, buffer
    IF s<0 THEN RETURN s, NULL END IF
    TRY
        LET json_out = util.JSONObject.parse( buffer.toString() )
    CATCH
        RETURN -301, NULL
    END TRY
    RETURN 0, json_out
END FUNCTION

PUBLIC FUNCTION do_request_to_json(
    http_req com.HttpRequest
) RETURNS (INTEGER, util.JSONObject)
    DEFINE http_resp com.HttpResponse
    DEFINE buffer base.StringBuffer
    DEFINE json_out util.JSONObject
    CALL http_req.setCharset("UTF-8")
    CALL http_req.setHeader(c_http_header_content_type, c_http_header_content_type_json)
    CALL http_req.setHeader(c_http_header_accept, c_http_header_content_type_json)
    TRY
        CALL http_req.doRequest()
        LET http_resp = http_req.getResponse()
        IF http_resp.getStatusCode() != 200 THEN
            LET _http_post_status = http_resp.getStatusCode()
            LET _http_post_description = http_resp.getStatusDescription()
            RETURN -201, NULL
        ELSE
            LET buffer = base.StringBuffer.create()
            CALL buffer.append(http_resp.getTextResponse())
        END IF
    CATCH
        RETURN -202, NULL
    END TRY
    TRY
        LET json_out = util.JSONObject.parse( buffer.toString() )
    CATCH
        RETURN -301, NULL
    END TRY
    RETURN 0, json_out
END FUNCTION

-- Common types

PUBLIC TYPE t_tool_signature_params DYNAMIC ARRAY OF RECORD
       name STRING,
       type STRING,
       enum DYNAMIC ARRAY OF STRING,
       description STRING,
       required BOOLEAN
    END RECORD

PUBLIC TYPE t_tool_function_dispatcher FUNCTION (
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER
