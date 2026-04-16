PACKAGE com.fourjs.aim

IMPORT FGL com.fourjs.aim.test_common
IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_vectors

FUNCTION main()
    DEFINE mode INTEGER
    DEFINE dim INTEGER
    DEFINE s INTEGER
    DEFINE client aim_vectors.t_client
    DEFINE request aim_vectors.t_text_embedding_request
    DEFINE response aim_vectors.t_text_embedding_response
    DEFINE source TEXT
    DEFINE vector STRING

    VAR param_list DYNAMIC ARRAY OF test_common.t_param_info = [
        (name: "provider",   description: "Embedding provider (openai/mistral/voyageai/gemini)", default_value: "gemini"),
        (name: "model",      description: "Model name",                                         default_value: "gemini-embedding-001"),
        (name: "dimensions", description: "Embedding dimensions",                                default_value: NULL),
        (name: "source",     description: "Source text file path",                               default_value: "README.md")
    ]

    VAR env_list DYNAMIC ARRAY OF test_common.t_env_info = [
        (description: "OpenAI API key (provider=openai)",
         env_var: "OPENAI_API_KEY", fglprofile: "aim.apikey.openai", required: FALSE),
        (description: "Gemini API key (provider=gemini)",
         env_var: "GEMINI_API_KEY", fglprofile: "aim.apikey.gemini", required: FALSE),
        (description: "Mistral API key (provider=mistral)",
         env_var: "MISTRAL_API_KEY", fglprofile: "aim.apikey.mistral", required: FALSE),
        (description: "VoyageAI API key (provider=voyageai)",
         env_var: "VOYAGE_API_KEY", fglprofile: "aim.apikey.voyageai", required: FALSE)
    ]

    LET mode = test_common.parse_args(param_list)
    IF mode == test_common.MODE_HELP THEN
        CALL test_common.show_usage(arg_val(0), "Text Embeddings", param_list, env_list)
        EXIT PROGRAM 0
    END IF

    CALL aim_common.initialize()

    CALL client.set_defaults(test_common.get_param("provider"), test_common.get_param("model"))

    IF test_common.has_param("dimensions") THEN
        LET dim = test_common.get_param("dimensions")
    ELSE
        LET dim = NULL
    END IF
    CALL request.set_defaults(client, dim)

    LOCATE source IN FILE test_common.get_param("source")
    CALL request.set_source(source)
    LET s = client.send_text_embedding_request(request, response)
    IF s == 0 THEN
       LET vector = response.get_vector()
       DISPLAY vector
    ELSE
       CALL test_common.show_error(s)
    END IF

    CALL aim_common.cleanup()

END FUNCTION
