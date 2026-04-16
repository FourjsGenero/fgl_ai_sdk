PACKAGE com.fourjs.aim

IMPORT FGL com.fourjs.aim.test_common
IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_ollama

FUNCTION main()
    DEFINE mode INTEGER
    DEFINE client aim_ollama.t_client
    DEFINE request aim_ollama.t_response_request
    DEFINE response aim_ollama.t_response
    DEFINE s INTEGER

    VAR param_list DYNAMIC ARRAY OF test_common.t_param_info = [
        (name: "model",       description: "Model name",                     default_value: "llama3.1"),
        (name: "system",      description: "System message",                 default_value: "You are a Math teacher. Answer with precise instructions."),
        (name: "prompt",      description: "User prompt",                    default_value: "How to compute the area of a circle?"),
        (name: "temperature", description: "Sampling temperature (0.0-1.0)", default_value: "0.7"),
        (name: "top_p",       description: "Nucleus sampling threshold",     default_value: NULL),
        (name: "top_k",       description: "Top-K sampling",                 default_value: NULL),
        (name: "min_p",       description: "Minimum probability threshold",  default_value: NULL),
        (name: "num_ctx",     description: "Context window size",            default_value: NULL),
        (name: "num_predict", description: "Maximum tokens to predict",      default_value: NULL),
        (name: "base_url",    description: "Ollama server host",             default_value: "localhost"),
        (name: "tcp_port",    description: "Ollama server port",             default_value: "11434")
    ]

    VAR env_list DYNAMIC ARRAY OF test_common.t_env_info = [
        (description: "No API key required for local Ollama instances",
         env_var: NULL, fglprofile: NULL, required: FALSE)
    ]

    LET mode = test_common.parse_args(param_list)
    IF mode == test_common.MODE_HELP THEN
        CALL test_common.show_usage(arg_val(0), "Ollama", param_list, env_list)
        EXIT PROGRAM 0
    END IF

    CALL aim_common.initialize()

    CALL client.set_defaults(test_common.get_param("model"))
    -- Apply client-level parameters
    LET client.connection.base_url = test_common.get_param("base_url")
    LET client.connection.tcp_port = test_common.get_param("tcp_port")

    CALL request.set_defaults(client)

    -- Apply request parameters
    LET request.options.temperature = test_common.get_param("temperature")
    IF test_common.has_param("top_p") THEN
        LET request.options.top_p = test_common.get_param("top_p")
    END IF
    IF test_common.has_param("top_k") THEN
        LET request.options.top_k = test_common.get_param("top_k")
    END IF
    IF test_common.has_param("min_p") THEN
        LET request.options.min_p = test_common.get_param("min_p")
    END IF
    IF test_common.has_param("num_ctx") THEN
        LET request.options.num_ctx = test_common.get_param("num_ctx")
    END IF
    IF test_common.has_param("num_predict") THEN
        LET request.options.num_predict = test_common.get_param("num_predict")
    END IF

    CALL request.set_system_message(test_common.get_param("system"))
    CALL request.set_prompt_message(test_common.get_param("prompt"))

    LET s = client.create_response(request, response)
    IF s == 0 THEN
       DISPLAY response.response
    ELSE
       CALL test_common.show_error(s)
    END IF

    CALL aim_common.cleanup()

END FUNCTION
