IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_vectors

FUNCTION main()
    DEFINE s INTEGER
    DEFINE client aim_vectors.t_client
    DEFINE request aim_vectors.t_text_embedding_request
    DEFINE response aim_vectors.t_text_embedding_response
    DEFINE source TEXT
    DEFINE vector STRING

    IF num_args()<>1 THEN
       DISPLAY SFMT("Usage: fglrun %1 <text-file>", arg_val(0))
       EXIT PROGRAM 1
    END IF

    CALL aim_common.initialize()

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
       DISPLAY aim_common.get_error_message(s)
       LET vector = NULL
    END IF

    CALL aim_common.cleanup()

END FUNCTION
