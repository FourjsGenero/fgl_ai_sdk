IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_ollama

FUNCTION main()
    DEFINE client aim_ollama.t_client
    DEFINE request aim_ollama.t_response_request
    DEFINE response aim_ollama.t_response
    DEFINE s INTEGER
    CALL aim_common.initialize()
    CALL client.set_defaults("llama3.1")
    -- No API key required...
    CALL request.set_defaults(client)
    CALL request.set_system_message("You are a Math teacher.\n Answer with precise instructions.")
    CALL request.set_prompt_message("How to compute the area of a circle?")
    LET s = client.create_response(request,response)
    IF s == 0 THEN
       DISPLAY response.response
    ELSE
       DISPLAY aim_common.get_error_message(s)
       DISPLAY "HTTP post status: ", aim_common.get_last_http_post_status()
       DISPLAY "HTTP post description : ", aim_common.get_last_http_post_description()
    END IF
    CALL aim_common.cleanup()
END FUNCTION
