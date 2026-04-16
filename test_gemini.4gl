IMPORT FGL test_common
IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_gemini

FUNCTION main()
    DEFINE mode INTEGER
    DEFINE client aim_gemini.t_client
    DEFINE request aim_gemini.t_text_request
    DEFINE response aim_gemini.t_text_response
    DEFINE x, tx, s INTEGER

    VAR param_list DYNAMIC ARRAY OF test_common.t_param_info = [
        (name: "model",             description: "Model name",                       default_value: "gemini-3-flash-preview"),
        (name: "system",            description: "System instruction",               default_value: "You are a Math teacher."),
        (name: "prompt",            description: "User prompt",                      default_value: "What is the quotient and remainder of 13 divided by 5?"),
        (name: "max_tokens",        description: "Maximum output tokens",            default_value: "2048"),
        (name: "temperature",       description: "Sampling temperature (0.0-1.0)",   default_value: "0.7"),
        (name: "top_p",             description: "Nucleus sampling threshold",       default_value: NULL),
        (name: "top_k",             description: "Top-K sampling",                   default_value: NULL),
        (name: "seed",              description: "Random seed",                      default_value: NULL),
        (name: "presence_penalty",  description: "Presence penalty",                 default_value: NULL),
        (name: "frequency_penalty", description: "Frequency penalty",                default_value: NULL),
        (name: "tools",             description: "Enable tool calling (true/false)", default_value: "true")
    ]

    VAR mycallback aim_common.t_tool_function_dispatcher = FUNCTION exec_tools

    VAR tps1 aim_common.t_tool_signature_params = [
          (name:"operand_1", type:"number", description:"First operand.", required: TRUE ),
          (name:"operand_2", type:"number", description:"Second operand.", required: TRUE )
        ]
    VAR tps2 aim_common.t_tool_signature_params = [
          (name:"dividend", type:"number", description:"The dividend operand.", required: TRUE ),
          (name:"divisor", type:"number", description:"The divisor operand.", required: TRUE )
        ]
    VAR tps3 aim_common.t_tool_signature_params = [
          (name:"location", type:"string", description:"The name of the place, city or street.", required: TRUE )
        ]

    VAR env_list DYNAMIC ARRAY OF test_common.t_env_info = [
        (description: "Gemini API key",
         env_var: "GEMINI_API_KEY", fglprofile: "aim.apikey.gemini", required: TRUE),
        (description: "Google project ID",
         env_var: "GOOGLE_PROJECT_ID", fglprofile: NULL, required: TRUE)
    ]

    LET mode = test_common.parse_args(param_list)
    IF mode == test_common.MODE_HELP THEN
        CALL test_common.show_usage(arg_val(0), "Gemini (Google)", param_list, env_list)
        EXIT PROGRAM 0
    END IF

    CALL aim_common.initialize()

    CALL client.set_defaults(test_common.get_param("model"))
    CALL request.set_defaults(client)

    -- Apply parameters
    LET request.generationConfig.maxOutputTokens = test_common.get_param("max_tokens")
    LET request.generationConfig.temperature = test_common.get_param("temperature")
    IF test_common.has_param("top_p") THEN
        LET request.generationConfig.topP = test_common.get_param("top_p")
    END IF
    IF test_common.has_param("top_k") THEN
        LET request.generationConfig.topK = test_common.get_param("top_k")
    END IF
    IF test_common.has_param("seed") THEN
        LET request.generationConfig.seed = test_common.get_param("seed")
    END IF
    IF test_common.has_param("presence_penalty") THEN
        LET request.generationConfig.presencePenalty = test_common.get_param("presence_penalty")
    END IF
    IF test_common.has_param("frequency_penalty") THEN
        LET request.generationConfig.frequencyPenalty = test_common.get_param("frequency_penalty")
    END IF

    CALL request.set_system_instruction(test_common.get_param("system"))

    IF test_common.get_param("tools") == "true" THEN
        -- Tool calling mode
        LET x = request.append_user_content(
            "Use the provided tools to generate the result for a user question.")
        LET tx = request.append_tool_definition("multiplication",
            "Multiplies two numbers.", tps1)
        LET tx = request.append_tool_definition("integer_division",
            "Divides two integer numbers and produces a quotient and remainder.", tps2)
        LET tx = request.append_tool_definition("gcs_coordinates",
            "Returns the geographic coordinate as latitude and longitude of a given place.", tps3)
        LET x = request.append_user_content(test_common.get_param("prompt"))

        LET s = client.create_response(request, response)
        WHILE s == 1 -- tool calls required, we loop until done
            LET s = client.continue_response(request, response, mycallback)
        END WHILE
    ELSE
        -- Simple completion mode
        LET x = request.append_user_content(test_common.get_param("prompt"))
        LET s = client.create_response(request, response)
    END IF

    IF s == 0 THEN
       DISPLAY response.get_content_text(1)
    ELSE
       CALL test_common.show_error(s)
    END IF

    CALL aim_common.cleanup()

END FUNCTION

FUNCTION exec_tools(
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER
    RETURN test_common.exec_tools(name, params, results)
END FUNCTION
