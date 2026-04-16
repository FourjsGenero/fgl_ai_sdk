IMPORT FGL test_common
IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_openai

FUNCTION main()
    DEFINE mode INTEGER
    DEFINE client aim_openai.t_client
    DEFINE request aim_openai.t_response_request
    DEFINE response aim_openai.t_response
    DEFINE x, tx, s INTEGER

    VAR param_list DYNAMIC ARRAY OF test_common.t_param_info = [
        (name: "model",       description: "Model name",                       default_value: "gpt-4o"),
        (name: "system",      description: "System instructions",              default_value: "You are a Math teacher."),
        (name: "prompt",      description: "User prompt",                      default_value: "What is the exact location of the city of London?"),
        (name: "max_tokens",  description: "Maximum output tokens",            default_value: "2048"),
        (name: "temperature", description: "Sampling temperature (0.0-1.0)",   default_value: "0.7"),
        (name: "top_p",       description: "Nucleus sampling threshold",       default_value: NULL),
        (name: "tools",       description: "Enable tool calling (true/false)", default_value: "true")
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
        (description: "OpenAI API key",
         env_var: "OPENAI_API_KEY", fglprofile: "aim.apikey.openai", required: TRUE),
        (description: "OpenAI organization ID",
         env_var: "OPENAI_ORGANIZATION_ID", fglprofile: NULL, required: FALSE),
        (description: "OpenAI project ID",
         env_var: "OPENAI_PROJECT_ID", fglprofile: NULL, required: FALSE)
    ]

    LET mode = test_common.parse_args(param_list)
    IF mode == test_common.MODE_HELP THEN
        CALL test_common.show_usage(arg_val(0), "OpenAI (GPT)", param_list, env_list)
        EXIT PROGRAM 0
    END IF

    CALL aim_common.initialize()

    CALL client.set_defaults(test_common.get_param("model"))
    CALL request.set_defaults(client)

    -- Apply parameters
    LET request.max_output_tokens = test_common.get_param("max_tokens")
    LET request.temperature = test_common.get_param("temperature")
    IF test_common.has_param("top_p") THEN
        LET request.top_p = test_common.get_param("top_p")
    END IF

    CALL request.set_instructions(test_common.get_param("system"))

    IF test_common.get_param("tools") == "true" THEN
        -- Tool calling mode
        LET x = request.append_user_input(
            "Use the provided tools to generate the result for a user question.")
        LET tx = request.append_tool_definition("multiplication",
            "Multiplies two numbers.", tps1)
        LET tx = request.append_tool_definition("integer_division",
            "Divides two integer numbers and produces a quotient and remainder.", tps2)
        LET tx = request.append_tool_definition("gcs_coordinates",
            "Returns the geographic coordinate as latitude and longitude of a given place.", tps3)
        LET x = request.append_user_input(test_common.get_param("prompt"))

        LET s = client.create_response(request, response)
        WHILE s == 1 -- tool calls required, we loop until done
            LET s = client.continue_response(request, response, mycallback)
        END WHILE
    ELSE
        -- Simple completion mode
        LET x = request.append_user_input(test_common.get_param("prompt"))
        LET s = client.create_response(request, response)
    END IF

    IF s == 0 THEN
       DISPLAY response.get_output_message_content_text(1,1)
    ELSE
       CALL test_common.show_error(s)
    END IF
    IF response.error.code IS NOT NULL THEN
       DISPLAY "Response error: ", response.error.code, " ", response.error.message
    END IF
    LET s = client.delete_response(response)
    DISPLAY "Delete response result: ", s

    CALL aim_common.cleanup()

END FUNCTION

FUNCTION exec_tools(
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER
    RETURN test_common.exec_tools(name, params, results)
END FUNCTION
