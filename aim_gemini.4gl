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

PUBLIC TYPE t_client RECORD
        connection RECORD
            provider STRING,
            secret_key STRING,
            project STRING,
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
PRIVATE CONSTANT _c_http_header_x_goog_api_key = "x-goog-api-key"
--PRIVATE CONSTANT _c_http_header_project = "x-goog-user-project" # FIXME? Not needed for Gemini APIs?

--PRIVATE CONSTANT _c_gemini_provider_<gemini-compatible-provider> = "xxx"

PRIVATE CONSTANT _c_gemini_url_version = "v1beta" -- If this changes, review all TYPE structures!
PRIVATE CONSTANT _c_gemini_url_template = "https://generativelanguage.googleapis.com/%1/models/%2:%3"

PRIVATE CONSTANT _c_role_model = "model"
PRIVATE CONSTANT _c_role_user  = "user"

PRIVATE FUNCTION _check_utf8() RETURNS BOOLEAN
    RETURN ( ORD("€") == 8364 )
END FUNCTION

PRIVATE FUNCTION _disp_error(msg STRING) RETURNS ()
    DISPLAY SFMT("GEMINI CLIENT ERROR: %1",msg)
END FUNCTION

PRIVATE FUNCTION _disp_warning(msg STRING) RETURNS ()
    DISPLAY SFMT("GEMINI CLIENT WARNING: %1",msg)
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
        ( num: -103, message: "No project id provided" ),
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
    IF length(client.connection.secret_key)==0 THEN
        RETURN -102
    END IF
    IF length(client.connection.project)==0 THEN
        RETURN -103
    END IF
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _build_server_url(
    client t_client,
    method STRING
) RETURNS STRING
    DEFINE res STRING
    LET res = SFMT(_c_gemini_url_template,
                   _c_gemini_url_version,
                   client.request.model,
                   method)
    RETURN res
END FUNCTION

PRIVATE FUNCTION _post_request_command_create(
    client t_client,
    method STRING
) RETURNS com.HttpRequest
    DEFINE http_req com.HttpRequest
    DEFINE endpoint STRING
    LET endpoint = _build_server_url(client,method)
--display "POST endpoint:", endpoint
    LET http_req = com.HttpRequest.Create(endpoint)
    CALL http_req.setConnectionTimeOut(client.connection.timeout)
    CALL http_req.setTimeOut(client.request.timeout)
    CALL http_req.setMethod("POST")
    CALL http_req.setHeader(_c_http_header_x_goog_api_key, client.connection.secret_key)
    # FIXME? Project ID does not seem to be needed...
    # IF client.connection.project IS NOT NULL THEN
    #     CALL http_req.setHeader(_c_http_header_project, client.connection.project)
    # END IF
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
    method STRING,
    json_in util.JSONObject
) RETURNS (INTEGER,base.StringBuffer)
    DEFINE http_req com.HttpRequest
    DEFINE http_resp com.HttpResponse
    DEFINE buffer base.StringBuffer
    LET http_req = _post_request_command_create(client,method)
    CALL http_req.setCharset("UTF-8")
    CALL http_req.setHeader(_c_http_header_content_type,_c_http_header_content_type_json)
    CALL http_req.setHeader(_c_http_header_accept,_c_http_header_content_type_json)
    TRY
        CALL http_req.doTextRequest(json_in.toString())
        LET http_resp=http_req.getResponse()
        IF http_resp.getStatusCode() != 200 THEN
           LET _http_post_status = http_resp.getStatusCode()
           LET _http_post_description = http_resp.getStatusDescription()
           RETURN -201, NULL
        ELSE
           LET buffer = base.StringBuffer.create()
           CALL buffer.append(http_resp.getTextResponse())
        END IF
    CATCH
        LET _http_request_status = status
        LET _http_request_errmsg = sqlca.sqlerrm
        RETURN -202, NULL
    END TRY
    RETURN 0, buffer
END FUNCTION

PRIVATE FUNCTION _post_request_command_json_to_json(
    client t_client,
    method STRING,
    json_in util.JSONObject
) RETURNS (INTEGER, util.JSONObject)
    DEFINE s INTEGER
    DEFINE buffer base.StringBuffer
    DEFINE json_out util.JSONObject
    CALL _post_request_command_json_to_string_buffer(client,method,json_in)
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
    -- Secret key and project id can also be set directly by caller
    LET client.connection.secret_key = fgl_getenv("GEMINI_API_KEY")
    LET client.connection.project = fgl_getenv("GOOGLE_PROJECT_ID")
    LET client.connection.timeout = 10
    LET client.request.model = model
    LET client.request.timeout = 60
END FUNCTION

PUBLIC TYPE t_content RECORD
        role STRING,
        parts DYNAMIC ARRAY OF util.JSONObject
    END RECORD

PUBLIC TYPE t_safety_setting RECORD
        category STRING, -- HARM_CATEGORY_*
        threshold STRING -- BLOCK_*
    END RECORD

PUBLIC TYPE t_generation_config RECORD
        stopSequences DYNAMIC ARRAY OF STRING,
        responseMimeType STRING,
        responseSchema util.JSONObject,
        #_responseJsonSchema STRING,
        responseModalities DYNAMIC ARRAY OF STRING,
        candidateCount INTEGER,
        maxOutputTokens INTEGER,
        temperature FLOAT,
        topP FLOAT,
        topK INTEGER,
        seed INTEGER,
        presencePenalty FLOAT,
        frequencyPenalty FLOAT,
        responseLogprobs BOOLEAN,
        enableEnhancedCivicAnswers BOOLEAN
    END RECORD

PUBLIC TYPE t_function_declaration RECORD
        name STRING,
        description STRING,
        parameters util.JSONObject
    END RECORD

PUBLIC TYPE t_tool RECORD
        functionDeclarations DYNAMIC ARRAY OF t_function_declaration
    END RECORD

PUBLIC TYPE t_text_request RECORD
        model STRING,
        systemInstruction t_content,
        contents DYNAMIC ARRAY OF t_content,
        safetySettings DYNAMIC ARRAY OF t_safety_setting,
        generationConfig t_generation_config,
        cachedContent STRING,
        tools DYNAMIC ARRAY OF t_tool
    END RECORD

PUBLIC FUNCTION (request t_text_request) set_defaults(
    client t_client
) RETURNS ()
    INITIALIZE request.* TO NULL
    LET request.model = client.request.model
    LET request.generationConfig.temperature = 0.7
    LET request.generationConfig.maxOutputTokens = 2048
END FUNCTION

PUBLIC TYPE t_safety_rating RECORD
        category STRING,
        probability STRING,
        blocked BOOLEAN
    END RECORD

PUBLIC TYPE t_citation_metadata RECORD
        citationSources DYNAMIC ARRAY OF RECORD
            startIndex INTEGER,
            endIndex INTEGER,
            uri STRING,
            license STRING
        END RECORD
    END RECORD

PUBLIC TYPE t_grounding_attribution RECORD
        sourceId util.JSONObject, -- groundingPassage or semanticRetrieverChunk
        content t_content
    END RECORD

PUBLIC TYPE t_web RECORD
        web RECORD
            uri STRING,
            title STRING
        END RECORD
    END RECORD

PUBLIC TYPE t_segment RECORD
        partIndex INTEGER,
        startIndex INTEGER,
        endIndex INTEGER,
        text STRING
    END RECORD

PUBLIC TYPE t_grounding_support RECORD
        groundingChunkIndices DYNAMIC ARRAY OF INTEGER,
        confidenceScores DYNAMIC ARRAY OF FLOAT,
        segment t_segment
    END RECORD

PUBLIC TYPE t_search_entry_point RECORD
        renderedContent STRING,
        sdkBlob STRING
    END RECORD

PUBLIC TYPE t_retrieval_metadata RECORD
        googleSearchDynamicRetrievalScore FLOAT
    END RECORD

PUBLIC TYPE t_grounding_metadata RECORD
        groundingChunks DYNAMIC ARRAY OF t_web,
        groundingSupports DYNAMIC ARRAY OF t_grounding_support,
        webSearchQueries DYNAMIC ARRAY OF STRING,
        searchEntryPoint t_search_entry_point,
        retrievalMetadata t_retrieval_metadata
    END RECORD

PUBLIC TYPE t_candidate RECORD
        content t_content,
        finishReason STRING,
        safetyRatings DYNAMIC ARRAY OF t_safety_rating,
        citationMetadata t_citation_metadata,
        tokenCount INTEGER,
        groundingAttributions DYNAMIC ARRAY OF t_grounding_attribution,
        groundingMetadata t_grounding_metadata,
        avgLogprobs FLOAT,
        index INTEGER
    END RECORD

PUBLIC TYPE t_prompt_feedback RECORD
        blockReason STRING,
        safetyRatings DYNAMIC ARRAY OF t_safety_rating
    END RECORD

PUBLIC TYPE t_modality_token_count RECORD
        modality STRING,
        tokenCount INTEGER
    END RECORD

PUBLIC TYPE t_usage_metadata RECORD
        promptTokenCount INTEGER,
        cachedContentTokenCount INTEGER,
        candidatesTokenCount INTEGER,
        toolUsePromptTokenCount INTEGER,
        thoughtsTokenCount INTEGER,
        totalTokenCount INTEGER,
        promptTokensDetails DYNAMIC ARRAY OF t_modality_token_count,
        cacheTokensDetails DYNAMIC ARRAY OF t_modality_token_count,
        candidatesTokensDetails DYNAMIC ARRAY OF t_modality_token_count,
        toolUsePromptTokensDetails DYNAMIC ARRAY OF t_modality_token_count
    END RECORD

PUBLIC TYPE t_text_response RECORD
        responseId STRING,
        candidates DYNAMIC ARRAY OF t_candidate,
        promptFeedback t_prompt_feedback,
        usageMetadata t_usage_metadata,
        modelVersion STRING
    END RECORD

PRIVATE FUNCTION _chat_append_content_as_string(
    req t_text_request INOUT,
    role STRING,
    content STRING
) RETURNS INTEGER
    DEFINE x INTEGER
    LET x = req.contents.getLength() + 1
    LET req.contents[x].role = role
    LET req.contents[x].parts[1] = util.JSONObject.create()
    CALL req.contents[x].parts[1].put("text",content)
    RETURN x
END FUNCTION

PRIVATE FUNCTION _chat_append_content_as_json_object(
    req t_text_request INOUT,
    role STRING,
    content util.JSONObject
) RETURNS INTEGER
    DEFINE x INTEGER
    LET x = req.contents.getLength() + 1
    LET req.contents[x].role = role
    LET req.contents[x].parts[1] = content
    RETURN x
END FUNCTION

PRIVATE FUNCTION _chat_append_content_part_as_json(
    req t_text_request INOUT,
    mx INTEGER,
    element util.JSONObject
) RETURNS INTEGER
    DEFINE x INTEGER
    LET x = req.contents[mx].parts.getLength() + 1
    LET req.contents[mx].parts[x] = element
    RETURN x
END FUNCTION

PUBLIC FUNCTION (req t_text_request) append_model_content(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_content_as_string(req, _c_role_model, content)
END FUNCTION

PUBLIC FUNCTION (req t_text_request) append_user_content(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_content_as_string(req, _c_role_user, content)
END FUNCTION

PUBLIC FUNCTION (req t_text_request) append_user_content_as_json_object(
    content util.JSONObject
) RETURNS INTEGER
    RETURN _chat_append_content_as_json_object(req, _c_role_user, content)
END FUNCTION

PUBLIC FUNCTION (req t_text_request) append_model_content_as_json_object(
    content util.JSONObject
) RETURNS INTEGER
    RETURN _chat_append_content_as_json_object(req, _c_role_model, content)
END FUNCTION

PRIVATE FUNCTION _append_user_content_tool_result(
    req t_text_request INOUT,
    tool_name STRING,
    tool_use_id STRING, -- Unused?
    results DICTIONARY OF STRING
) RETURNS INTEGER
    DEFINE fr, rr, rv util.JSONObject
    CALL _assert(tool_name IS NOT NULL,"Missing tool name")
    CALL _assert(tool_use_id IS NOT NULL,"Missing tool use id")
    LET fr = util.JSONObject.create()
    LET rr = util.JSONObject.create()
    CALL rr.put("name",tool_name)
    LET rv = util.JSONObject.fromFGL(results)
    CALL rr.put("response",rv)
    CALL fr.put("functionResponse",rr)
    RETURN _chat_append_content_as_json_object(req, _c_role_user, fr)
END FUNCTION

PUBLIC FUNCTION (req t_text_request) clear_contents() RETURNS ()
    CALL req.contents.clear()
END FUNCTION

PUBLIC TYPE t_tool_signature_params DYNAMIC ARRAY OF RECORD
       name STRING,
       type STRING,
       enum DYNAMIC ARRAY OF STRING,
       description STRING,
       required BOOLEAN
    END RECORD

PUBLIC FUNCTION (req t_text_request) append_tool_definition(
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
    -- Warning: tools is an array with the sub-array functionDeclarations
    IF req.tools.getLength()==0 THEN
       CALL req.tools.appendElement()
    END IF
    CALL req.tools[1].functionDeclarations.appendElement()
    LET x = req.tools[1].functionDeclarations.getLength()
    LET req.tools[1].functionDeclarations[x].name = name
    LET req.tools[1].functionDeclarations[x].description = description
    LET req.tools[1].functionDeclarations[x].parameters = util.JSONObject.create()
    CALL req.tools[1].functionDeclarations[x].parameters.put("type","object")
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
    CALL req.tools[1].functionDeclarations[x].parameters.put("properties",properties)
    CALL req.tools[1].functionDeclarations[x].parameters.put("required",required)
    RETURN x
END FUNCTION

PUBLIC FUNCTION (res t_text_response) get_content_text(
    x INTEGER
) RETURNS STRING
    DEFINE buf base.StringBuffer
    DEFINE px, len INTEGER
    CALL _assert( (x>0), SFMT("Invalid content index: %1",x) )
    IF x<1 AND x > res.candidates.getLength() THEN
        RETURN NULL
    END IF
    LET buf = base.StringBuffer.create()
    LET len = res.candidates[x].content.parts.getLength()
    FOR px = 1 TO len
        IF res.candidates[x].content.parts[px].has("text") THEN
            CALL buf.append( res.candidates[x].content.parts[px].get("text") )
        END IF
    END FOR
    RETURN buf.toString()
END FUNCTION

PRIVATE FUNCTION _chat_append_system_instruction_part_as_string(
    req t_text_request INOUT,
    content STRING
) RETURNS INTEGER
    DEFINE x INTEGER
    LET x = req.systemInstruction.parts.getLength() + 1
    LET req.systemInstruction.parts[x] = util.JSONObject.create()
    CALL req.systemInstruction.parts[x].put("text",content)
    RETURN x
END FUNCTION

PRIVATE FUNCTION _chat_append_system_instruction_part_as_json(
    req t_text_request INOUT,
    element util.JSONObject
) RETURNS INTEGER
    DEFINE x INTEGER
    LET x = req.systemInstruction.parts.getLength() + 1
    LET req.systemInstruction.parts[x] = element
    RETURN x
END FUNCTION

PUBLIC FUNCTION (req t_text_request) set_system_instruction(
    content STRING
) RETURNS ()
    DEFINE x INTEGER
    INITIALIZE req.systemInstruction.* TO NULL
    LET x = _chat_append_system_instruction_part_as_string(req, content)
END FUNCTION

PUBLIC FUNCTION (req t_text_request) append_system_instruction_content_part(
    content STRING
) RETURNS INTEGER
    RETURN _chat_append_system_instruction_part_as_string(req, content)
END FUNCTION

PUBLIC FUNCTION (req t_text_request) remove_system_instruction() RETURNS ()
    CALL req.systemInstruction.parts.clear()
END FUNCTION

PUBLIC FUNCTION (req t_text_request) remove_system_instruction_part(
    x INTEGER
) RETURNS ()
    CALL _assert( (x>0 AND x<=req.systemInstruction.parts.getLength()),
                  SFMT("Invalid part index: %1",x) )
    CALL req.systemInstruction.parts.deleteElement(x)
END FUNCTION

PUBLIC FUNCTION (req t_text_request) has_system_instruction() RETURNS BOOLEAN
    RETURN ( req.systemInstruction.parts.getLength() > 0 )
END FUNCTION

PUBLIC FUNCTION (client t_client) create_response(
    request t_text_request,
    response t_text_response INOUT
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject
    INITIALIZE response.* TO NULL
    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
--display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"generateContent",json_in)
        RETURNING s, json_out
    IF s<0 THEN RETURN s END IF
    TRY
       CALL json_out.toFGL(response)
    CATCH
       RETURN -401
    END TRY
--display "json_out:\n", util.JSON.format( json_out.toString() )
    IF _get_response_candidate_function_call_at(response,1) IS NOT NULL THEN
       RETURN 1
    END IF
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _get_response_candidate_function_call_at(
    response t_text_response,
    index INTEGER
) RETURNS util.JSONObject
    DEFINE jo, jofc util.JSONObject
    DEFINE x, ix INTEGER
    IF index IS NULL OR index<1 THEN RETURN NULL END IF
    IF response.candidates.getLength()>=1 THEN
       IF response.candidates[1].content.role == "model"
       AND response.candidates[1].finishReason == "STOP"
       THEN
          FOR x=1 TO response.candidates[1].content.parts.getLength()
             LET jo = response.candidates[1].content.parts[x]
             LET jofc = jo.get("functionCall")
             IF jofc IS NOT NULL THEN
                LET ix=ix+1
                IF ix==index THEN RETURN jofc END IF
             END IF
          END FOR
       END IF
    END IF
    RETURN NULL
END FUNCTION

PUBLIC TYPE t_tool_function_dispatcher FUNCTION (
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER

PUBLIC FUNCTION (client t_client) continue_response(
    request t_text_request,
    response t_text_response INOUT,
    func_exec t_tool_function_dispatcher
) RETURNS INTEGER
    DEFINE s INTEGER
    DEFINE x, mx, px INTEGER
    DEFINE jo_function_call util.JSONObject
    DEFINE jo_args util.JSONObject
    DEFINE tool_name STRING
    DEFINE tool_use_id STRING
    -- WARNING: No tool id with Gemini? What in case of multiple function calls?
    -- OR is it thoughtSignature ?
    DEFINE params DICTIONARY OF STRING
    DEFINE results DICTIONARY OF STRING
    DEFINE json_in util.JSONObject
    DEFINE json_out util.JSONObject

--display "\nCONTINUING CONVERSATION WITH TOOL CALLS:"

    LET s = _check_client_info(client)
    IF s<0 THEN RETURN s END IF

    LET jo_function_call = _get_response_candidate_function_call_at(response,1)
    CALL _assert((jo_function_call IS NOT NULL),"Expecting functionCall response candidate")

    LET mx = request.append_model_content_as_json_object(response.candidates[1].content.parts[1])

    LET x = 0
    WHILE TRUE
        LET x = x + 1
        LET jo_function_call = _get_response_candidate_function_call_at(response,x)
        IF jo_function_call IS NULL THEN EXIT WHILE END IF

        LET tool_name = jo_function_call.get("name")
        LET tool_use_id = jo_function_call.get("id")

        CALL params.clear()
--display " *** jo_function_call: ", jo_function_call.toString()
        IF jo_function_call.has("args") THEN
           LET jo_args = jo_function_call.get("args")
           FOR px=1 TO jo_args.getLength()
               LET params[jo_args.name(px)] = jo_args.get(jo_args.name(px))
           END FOR
        END IF
        CALL results.clear()
        LET s = func_exec(tool_name,params,results)
        IF s < 0 THEN
           RETURN -501
        END IF
--display " *** results: ", util.JSON.stringify(results)
        LET mx = _append_user_content_tool_result(request,tool_name,tool_use_id,results)

    END WHILE

    INITIALIZE response.* TO NULL
    LET json_in = util.JSONObject.parse(util.JSON.stringifyOmitNulls(request))
--display "json_in:\n", util.JSON.format( json_in.toString() )
    CALL _post_request_command_json_to_json(client,"generateContent",json_in)
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
    DEFINE request t_text_request
    DEFINE response t_text_response
    DEFINE x, tx, s INTEGER

    CALL initialize()

    CALL client.set_defaults("gemini-3-flash-preview")
    -- Can set API key here instead of using an env var
    -- LET client.connection.secret_key = "xxx"

{
    -- Simple request
    CALL request.set_defaults(client)
    CALL request.set_system_instruction("You are a Math teacher.")
    LET x = request.append_system_instruction_content_part("Answer with precise instructions.")
    LET x = request.append_user_content("How to compute the area of a circle?")
    LET s = client.create_response(request,response)
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
    CALL request.set_system_instruction("You are a Math teacher.")
    LET x = request.append_user_content("Use the provided tools to generate the result for a user question.")

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

    --LET x = request.append_user_content("How much is 25 multiplied by 5?")
    LET x = request.append_user_content("What is the quotient and remainder of 13 divided by 5?")
    --LET x = request.append_user_content("What is the exact location of the city of London?")

    LET s = client.create_response(request,response)
    WHILE s == 1 -- tool calls required, we loop until done
        LET s = client.continue_response(request,response,mycallback)
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
