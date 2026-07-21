IMPORT FGL aim_vectors

MAIN
    DEFINE s INTEGER
    DEFINE client aim_vectors.t_client
    DEFINE request aim_vectors.t_text_embedding_request
    DEFINE response aim_vectors.t_text_embedding_response
    DEFINE source TEXT
    DEFINE vector STRING

    IF num_args()<>2 THEN
       DISPLAY SFMT("Usage: fglrun %1 <text-file> <provider>", arg_val(0))
       DISPLAY " where <provider> is one of: openai, voyageai, mistral, gemini"
       EXIT PROGRAM 1
    END IF

    CALL aim_vectors.initialize()

    CASE arg_val(2)
    WHEN "openai"
        CALL client.set_defaults("openai","text-embedding-3-small")
        CALL request.set_defaults(client,1024)
    WHEN "mistral"
        CALL client.set_defaults("mistral","mistral-embed")
        CALL request.set_defaults(client,NULL) -- dim is always 1024 with mistral
    WHEN "voyageai"
        CALL client.set_defaults("voyageai","voyage-3-large")
        CALL request.set_defaults(client,NULL)
    WHEN "gemini"
        CALL client.set_defaults("gemini","gemini-embedding-001")
        CALL request.set_defaults(client,1024)
    OTHERWISE
       DISPLAY "Missing vector embeddings provider."
       EXIT PROGRAM 1
    END CASE

    LOCATE source IN FILE arg_val(1)
    CALL request.set_source(source)
    LET s = client.send_text_embedding_request(request,response)
    IF s == 0 THEN
       LET vector = response.get_vector()
       DISPLAY vector
    ELSE
       DISPLAY aim_vectors.get_error_message(s)
       LET vector = NULL
    END IF

    CALL aim_vectors.cleanup()

END MAIN
