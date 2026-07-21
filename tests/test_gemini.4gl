IMPORT FGL aim_gemini

MAIN
    DEFINE client aim_gemini.t_client
    DEFINE request aim_gemini.t_text_request
    DEFINE response aim_gemini.t_text_response
    DEFINE x, tx, s INTEGER

    CALL aim_gemini.initialize()

    CALL client.set_defaults("gemini-3-flash-preview")
    -- Can set API key here instead of using an env var
    -- LET client.connection.secret_key = "xxx"

    IF arg_val(1) == "simple" THEN

    -- Simple request
    CALL request.set_defaults(client)
    CALL request.set_system_instruction("You are a Math teacher.")
    LET x = request.append_system_instruction_content_part("Answer with precise instructions.")
    LET x = request.append_user_content("How to compute the area of a circle?")
    LET s = client.create_response(request,response)
    IF s == 0 THEN
       DISPLAY response.get_content_text(1)
    ELSE
       DISPLAY aim_gemini.get_error_message(s)
       DISPLAY "HTTP post status: ", aim_gemini.get_last_http_post_status()
       DISPLAY "HTTP post description : ", aim_gemini.get_last_http_post_description()
    END IF

    ELSE

    -- Request with tools

    CALL request.set_defaults(client)

    VAR mycallback aim_gemini.t_tool_function_dispatcher = FUNCTION exec_tools
    CALL request.set_system_instruction("You are a Math teacher.")
    LET x = request.append_user_content("Use the provided tools to generate the result for a user question.")

    VAR tps1 aim_gemini.t_tool_signature_params = [
          (name:"operand_1", type:"number", description:"First operand.", required: TRUE ),
          (name:"operand_2", type:"number", description:"Second operand.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("multiplication","Multiplies two numbers.",tps1)

    VAR tps2 aim_gemini.t_tool_signature_params = [
          (name:"dividend", type:"number", description:"The dividend operand.", required: TRUE ),
          (name:"divisor", type:"number", description:"The divisor operand.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("integer_division","Divides two integer numbers and produces a quotient and remainder.",tps2)

    VAR tps3 aim_gemini.t_tool_signature_params = [
          (name:"location", type:"string", description:"The name of the place, city or street.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("gcs_coordinates","Returns the geographic coordinate as latitude and longitude of a given place.",tps3)

    --LET x = request.append_user_content("How much is 25 multiplied by 5?")
    --LET x = request.append_user_content("What is the quotient and remainder of 13 divided by 5?")
    LET x = request.append_user_content("What is the exact location of the city of London?")

    LET s = client.create_response(request,response)
    WHILE s == 1 -- tool calls required, we loop until done
        LET s = client.continue_response(request,response,mycallback)
    END WHILE
    IF s == 0 THEN
       DISPLAY response.get_content_text(1)
    ELSE
       DISPLAY aim_gemini.get_error_message(s)
       DISPLAY "HTTP post status: ", aim_gemini.get_last_http_post_status()
       DISPLAY "HTTP post description : ", aim_gemini.get_last_http_post_description()
    END IF

    END IF

    CALL aim_gemini.cleanup()

END MAIN

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
