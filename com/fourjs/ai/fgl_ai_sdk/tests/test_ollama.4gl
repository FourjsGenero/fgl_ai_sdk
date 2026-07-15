PACKAGE com.fourjs.ai.fgl_ai_sdk.tests

IMPORT FGL com.fourjs.ai.fgl_ai_sdk.aim_ollama

MAIN
    DEFINE client aim_ollama.t_client
    DEFINE request aim_ollama.t_response_request
    DEFINE response aim_ollama.t_response
    DEFINE s INTEGER
    CALL aim_ollama.initialize()
    CALL client.set_defaults("llama3.1")
    -- No API key required...
    CALL request.set_defaults(client)
    CALL request.set_system_message("You are a Math teacher.\n Answer with precise instructions.")
    CALL request.set_prompt_message("How to compute the area of a circle?")
    LET s = client.create_response(request,response)
    IF s == 0 THEN
       DISPLAY response.response
    ELSE
       DISPLAY aim_ollama.get_error_message(s)
       DISPLAY "HTTP post status: ", aim_ollama.get_last_http_post_status()
       DISPLAY "HTTP post description : ", aim_ollama.get_last_http_post_description()
    END IF
    CALL aim_ollama.cleanup()
END MAIN
