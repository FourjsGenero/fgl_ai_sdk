PACKAGE com.fourjs.aim

IMPORT FGL com.fourjs.aim.aim_common

PUBLIC CONSTANT MODE_HELP    = 0
PUBLIC CONSTANT MODE_DEFAULT = 1
PUBLIC CONSTANT MODE_CUSTOM  = 2

PUBLIC TYPE t_param_info RECORD
    name STRING,
    description STRING,
    default_value STRING
END RECORD

PUBLIC TYPE t_env_info RECORD
    description STRING,
    env_var STRING,
    fglprofile STRING,
    required BOOLEAN
END RECORD

PRIVATE DEFINE _params DICTIONARY OF STRING

PUBLIC FUNCTION get_param(name STRING) RETURNS STRING
    RETURN _params[name]
END FUNCTION

PUBLIC FUNCTION has_param(name STRING) RETURNS BOOLEAN
    RETURN _params.contains(name)
END FUNCTION

PRIVATE FUNCTION pad_string(s STRING, width INTEGER) RETURNS STRING
    DEFINE result STRING
    LET result = s
    WHILE result.getLength() < width
        LET result = result, " "
    END WHILE
    RETURN result
END FUNCTION

PUBLIC FUNCTION parse_args(
    param_list DYNAMIC ARRAY OF t_param_info
) RETURNS INTEGER
    DEFINE i, pos INTEGER
    DEFINE arg STRING
    CALL _params.clear()
    -- Fill defaults
    FOR i = 1 TO param_list.getLength()
        IF param_list[i].default_value IS NOT NULL THEN
            LET _params[param_list[i].name] = param_list[i].default_value
        END IF
    END FOR
    IF num_args() == 0 THEN
        RETURN MODE_HELP
    END IF
    -- Parse arguments
    FOR i = 1 TO num_args()
        LET arg = arg_val(i)
        CASE
        WHEN arg == "--default"
            RETURN MODE_DEFAULT
        WHEN arg == "--help"
            RETURN MODE_HELP
        OTHERWISE
            LET pos = arg.getIndexOf("=", 1)
            IF pos > 1 THEN
                IF pos < arg.getLength() THEN
                    LET _params[arg.subString(1, pos - 1)] =
                        arg.subString(pos + 1, arg.getLength())
                ELSE
                    LET _params[arg.subString(1, pos - 1)] = ""
                END IF
            ELSE
                DISPLAY SFMT("WARNING: Ignoring invalid argument '%1'", arg)
            END IF
        END CASE
    END FOR
    RETURN MODE_CUSTOM
END FUNCTION

PUBLIC FUNCTION show_usage(
    program_name STRING,
    provider_label STRING,
    param_list DYNAMIC ARRAY OF t_param_info,
    env_list DYNAMIC ARRAY OF t_env_info
) RETURNS ()
    DEFINE i INTEGER
    DEFINE line STRING
    DEFINE tag STRING
    DISPLAY ""
    DISPLAY SFMT("Usage: fglrun %1 [OPTIONS] [key=value ...]", program_name)
    DISPLAY ""
    DISPLAY SFMT("  Test program for the %1 AI provider.", provider_label)
    DISPLAY ""
    DISPLAY "Options:"
    DISPLAY "  --default    Run with default hard-coded parameters"
    DISPLAY "  --help       Display this usage message"
    DISPLAY ""
    DISPLAY "Parameters:"
    FOR i = 1 TO param_list.getLength()
        LET line = "  ", pad_string(param_list[i].name, 24),
                   param_list[i].description
        IF param_list[i].default_value IS NOT NULL THEN
            LET line = line, " (default: ", param_list[i].default_value, ")"
        END IF
        DISPLAY line
    END FOR
    IF env_list.getLength() > 0 THEN
        DISPLAY ""
        DISPLAY "Environment:"
        FOR i = 1 TO env_list.getLength()
            IF env_list[i].required THEN
                LET tag = " (required)"
            ELSE
                LET tag = " (optional)"
            END IF
            LET line = "  ", env_list[i].description, tag
            DISPLAY line
            IF env_list[i].env_var IS NOT NULL THEN
                DISPLAY "    env var:    ", env_list[i].env_var
            END IF
            IF env_list[i].fglprofile IS NOT NULL THEN
                DISPLAY "    fglprofile: ", env_list[i].fglprofile
            END IF
        END FOR
    END IF
    DISPLAY ""
END FUNCTION

PUBLIC FUNCTION show_error(s INTEGER) RETURNS ()
    DISPLAY aim_common.get_error_message(s)
    DISPLAY "HTTP post status: ", aim_common.get_last_http_post_status()
    DISPLAY "HTTP post description: ", aim_common.get_last_http_post_description()
END FUNCTION

PUBLIC FUNCTION exec_tools(
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER
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
