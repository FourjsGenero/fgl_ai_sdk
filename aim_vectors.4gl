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
    DISPLAY SFMT("VECTOR EMBEDDINGS LIB ERROR: %1",msg)
END FUNCTION

PRIVATE FUNCTION _disp_warning(msg STRING) RETURNS ()
    DISPLAY SFMT("VECTOR EMBEDDINGS LIB WARNING: %1",msg)
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
        ( num: -202, message: "HTTP POST request error" )
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
    service STRING
) RETURNS STRING
    DEFINE res STRING
    CASE client.connection.provider
    WHEN _c_oai_provider_gemini
       LET res = SFMT(_c_gemini_url_template,
                      _c_gemini_url_version,
                      client.request.model,
                      "embedContent")
    OTHERWISE
       LET res = SFMT("https://%1/%2/%3",
                      client.connection.base_url,
                      _c_openai_url_version,
                      service)
    END CASE
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
    CASE client.connection.provider
    WHEN _c_oai_provider_anthropic
        CALL http_req.setHeader(_c_http_header_x_api_key, client.connection.secret_key)
        CALL http_req.setHeader(_c_http_header_anthropic_version, _c_openai_anthropic_version)
    WHEN _c_oai_provider_gemini
        CALL http_req.setHeader(_c_http_header_x_goog_api_key, client.connection.secret_key)
    OTHERWISE
        CALL http_req.setHeader(_c_http_header_authorization, SFMT("Bearer %1", client.connection.secret_key))
    END CASE
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
    CALL _post_request_command_json_to_string_buffer(client, service, json_in)
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
    provider STRING,
    model STRING
) RETURNS ()
    INITIALIZE client.* TO NULL
    CASE provider
    WHEN _c_oai_provider_openai
      LET client.connection.provider = provider
      LET client.connection.base_url = "api.openai.com"
      LET client.connection.secret_key = fgl_getenv("OPENAI_API_KEY")
      LET client.connection.organization = fgl_getenv("OPENAI_ORGANIZATION_ID")
      LET client.connection.project = fgl_getenv("OPENAI_PROJECT_ID")
    WHEN _c_oai_provider_anthropic
      LET client.connection.provider = provider
      LET client.connection.base_url = "api.anthropic.com"
      LET client.connection.secret_key = fgl_getenv("ANTHROPIC_API_KEY")
    WHEN _c_oai_provider_mistral
      LET client.connection.provider = provider
      LET client.connection.base_url = "api.mistral.ai"
      LET client.connection.secret_key = fgl_getenv("MISTRAL_API_KEY")
    WHEN _c_oai_provider_voyageai
      LET client.connection.provider = provider
      LET client.connection.base_url = "api.voyageai.com"
      LET client.connection.secret_key = fgl_getenv("VOYAGE_API_KEY")
    WHEN _c_oai_provider_gemini
      LET client.connection.provider = provider
      LET client.connection.base_url = "generativelanguage.googleapis.com"
      LET client.connection.secret_key = fgl_getenv("GEMINI_API_KEY")
    OTHERWISE
      CALL _assert(FALSE,"Invalid provider")
    END CASE
    LET client.connection.timeout = 10
    LET client.request.model = model
    LET client.request.timeout = 60
END FUNCTION

PUBLIC TYPE t_client RECORD
        connection RECORD
            provider STRING,
            base_url STRING,
            secret_key STRING,
            organization STRING,
            project STRING,
            timeout INTEGER
        END RECORD,
        request RECORD
            model STRING,
            timeout INTEGER
        END RECORD
    END RECORD

PRIVATE CONSTANT _c_http_header_content_type = "Content-Type"
#PRIVATE CONSTANT _c_http_header_content_disposition = "Content-Disposition"
PRIVATE CONSTANT _c_http_header_content_type_json = "application/json"
#PRIVATE CONSTANT _c_http_header_content_type_bytes = "application/octet-stream"

PRIVATE CONSTANT _c_http_header_accept = "Accept"
PRIVATE CONSTANT _c_http_header_authorization= "Authorization"
PRIVATE CONSTANT _c_http_header_organization = "OpenAI-Organization"
PRIVATE CONSTANT _c_http_header_project = "OpenAI-Project"

PRIVATE CONSTANT _c_http_header_x_api_key = "x-api-key"
PRIVATE CONSTANT _c_http_header_anthropic_version = "anthropic-version"

PRIVATE CONSTANT _c_http_header_x_goog_api_key = "x-goog-api-key"

--PRIVATE CONSTANT _c_oai_provider_localhost  = "localhost" -- testing
PRIVATE CONSTANT _c_oai_provider_openai  = "openai"
PRIVATE CONSTANT _c_oai_provider_mistral = "mistral"
PRIVATE CONSTANT _c_oai_provider_anthropic = "anthropic"
PRIVATE CONSTANT _c_oai_provider_gemini = "gemini"
PRIVATE CONSTANT _c_oai_provider_voyageai = "voyageai"

PRIVATE CONSTANT _c_openai_url_version = "v1"
PRIVATE CONSTANT _c_openai_anthropic_version = "2023-06-01"

PRIVATE CONSTANT _c_gemini_url_version = "v1beta"
PRIVATE CONSTANT _c_gemini_url_template = "https://generativelanguage.googleapis.com/%1/models/%2:%3"

PUBLIC TYPE t_content RECORD
        parts DYNAMIC ARRAY OF RECORD
            text STRING
        END RECORD
    END RECORD

PUBLIC TYPE t_text_embedding_request RECORD
        input DYNAMIC ARRAY OF STRING, -- OpenAI and others
        content t_content, -- Gemini
        model STRING,
        dimensions INTEGER,
        encoding_format STRING,
        user STRING
    END RECORD

PUBLIC TYPE t_text_embedding_response RECORD
        object STRING, -- "list"
        data DYNAMIC ARRAY OF RECORD
            object STRING, -- "embedding"
            index INTEGER,
            embedding DYNAMIC ARRAY OF FLOAT
        END RECORD,
        model STRING,
        usage RECORD
            prompt_tokens INTEGER,
            total_tokens INTEGER
        END RECORD
    END RECORD

PUBLIC FUNCTION (request t_text_embedding_request) set_defaults(
    client t_client,
    dimensions INTEGER
) RETURNS ()
    INITIALIZE request.* TO NULL
    LET request.model = client.request.model
    IF dimensions IS NOT NULL THEN
        LET request.dimensions = dimensions
    END IF
END FUNCTION

PUBLIC FUNCTION (request t_text_embedding_request) set_source(
    source STRING
) RETURNS ()
    CALL request.input.clear()
    INITIALIZE request.content.* TO NULL
    CASE
    WHEN request.model MATCHES "gemini*"
        LET request.content.parts[1].text = source
    OTHERWISE
        LET request.input[1] = source
    END CASE
END FUNCTION

PUBLIC FUNCTION (client t_client) send_text_embedding_request(
    request t_text_embedding_request,
    response t_text_embedding_response INOUT
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject
    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"embeddings",json_in)
         RETURNING s, json_out
    IF s<0 THEN RETURN s END IF
display "json_out:\n", util.JSON.format( json_out.toString() )
    CALL json_out.toFGL(response)
    RETURN 0
END FUNCTION

PUBLIC FUNCTION (response t_text_embedding_response) get_vector() RETURNS STRING
    IF response.data.getLength()>0 THEN
       RETURN util.JSON.stringify(response.data[1].embedding)
    ELSE
       RETURN NULL
    END IF
END FUNCTION

PUBLIC FUNCTION main()
    DEFINE s INTEGER
    DEFINE client t_client
    DEFINE request t_text_embedding_request
    DEFINE response t_text_embedding_response
    DEFINE source TEXT
    DEFINE vector STRING

    IF num_args()<>1 THEN
       DISPLAY SFMT("Usage: fglrun %1 <text-file>", arg_val(0))
       EXIT PROGRAM 1
    END IF

    CALL initialize()

    --CALL client.set_defaults("openai","text-embedding-3-small")
    --CALL request.set_defaults(client,1024)

    --CALL client.set_defaults("mistral","mistral-embed")
    --CALL request.set_defaults(client,NULL) -- dim is always 1024 with mistral

    --CALL client.set_defaults("voyageai","voyage-3-large")
    --CALL request.set_defaults(client,NULL)

    CALL client.set_defaults("gemini","gemini-embedding-001")
    CALL request.set_defaults(client,NULL)

    LOCATE source IN FILE arg_val(1)
    CALL request.set_source(source)
    LET s = client.send_text_embedding_request(request,response)
    IF s == 0 THEN
       LET vector = response.get_vector()
       DISPLAY vector
    ELSE
       DISPLAY get_error_message(s)
       LET vector = NULL
    END IF

    CALL cleanup()

END FUNCTION
