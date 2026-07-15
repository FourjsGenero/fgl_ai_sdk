# FGL SDK for Artificial Intelligence APIs

## Description

This project contains a set of Genero BDL modules to interface with AI provider APIs.

## Disclaimer

THIS SOURCE CODE IS PROVIDED "AS IS" AND "WITH ALL FAULTS." FOURJS AND THE AUTHORS MAKE NO
GUARANTEES OR WARRANTIES OF ANY KIND CONCERNING THE SAFETY, RELIABILITY, OR SUITABILITY OF
THE SOFTWARE FOR ANY MAIN OR PARTICULAR PURPOSE.

IN NO EVENT SHALL FOURJS, THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

THIS SDK IS A CONNECTOR AND REQUIRES A THIRD-PARTY AI PROVIDER, A COMPATIBLE LARGE LANGUAGE
MODEL (LLM), AND A VALID API KEY. USERS ARE SOLELY RESPONSIBLE FOR ANY COSTS, USAGE LIMITS,
AND TERMS OF SERVICE ASSOCIATED WITH THEIR CHOSEN AI PROVIDER.

USING THIS SOFTWARE INVOLVES TRANSMITTING DATA TO THIRD-PARTY SERVICES. BEFORE PROCEEDING,
YOU MUST EVALUATE THE SECURITY, PRIVACY, AND CONFIDENTIALITY IMPLICATIONS OF SHARING SENSITIVE
INFORMATION WITH THESE PROVIDERS. THE AUTHORS ARE NOT LIABLE FOR ANY DATA BREACHES OR MISUSE
OF INFORMATION BY THIRD-PARTY AI ENTITIES.

## Overview

The FGL AI SDK package (`com.fourjs.ai.fgl_ai_sdk`) provides a Genero BDL library for
integrating with AI provider APIs. It supports text generation (chat completions) and
text embedding across multiple providers through a consistent module structure.

| Service | Module | Provider |
|---------|--------|----------|
| **Text Generation** | `aim_anthropic` | Anthropic / Claude |
| **Text Generation** | `aim_openai` | OpenAI / GPT |
| **Text Generation** | `aim_gemini` | Google / Gemini |
| **Text Generation** | `aim_mistral` | Mistral |
| **Text Generation** | `aim_ollama` | Ollama (local) |
| **Text Embedding** | `aim_vectors` | OpenAI, Gemini, Mistral, VoyageAI |
| **Test Program** | `test_anthropic` | Anthropic / Claude |
| **Test Program** | `test_openai` | OpenAI / GPT |
| **Test Program** | `test_gemini` | Google / Gemini |
| **Test Program** | `test_mistral` | Mistral |
| **Test Program** | `test_ollama` | Ollama (local) |
| **Test Program** | `test_vectors` | Text Embeddings |

Each provider module follows the same pattern: create a client, configure a request,
send it, and process the response. All modules belong to the `com.fourjs.ai.fgl_ai_sdk`
FGL package.

## License

This source code is under [MIT license](./LICENSE)

## Prerequisites

- Genero BDL 6.x or later
* GNU Make
- An API key from at least one supported AI provider


## AI Concepts

### Text Generation (Chat Completion)

Text generation APIs accept a conversation (a sequence of messages with roles like
"user", "assistant", and "system") and return a model-generated response. Common
use cases include:

- **Chat assistants** -- multi-turn conversations with context
- **Content generation** -- drafting text, summaries, translations
- **Structured output** -- generating JSON responses conforming to a schema
- **Tool use (function calling)** -- the model can request execution of tools you
  define, enabling it to retrieve data or perform actions

The SDK supports tool use for Anthropic, OpenAI, Gemini, and Mistral. You define
tool signatures with parameter schemas, and the SDK handles the request/response
cycle including tool result submission.

### Text Embedding

Text embedding APIs convert text into dense numeric vectors (arrays of floats) that
capture semantic meaning. These vectors can be used for:

- **Semantic search** -- find documents similar to a query
- **Clustering** -- group related content
- **Classification** -- categorize text by comparing embeddings
- **RAG (Retrieval-Augmented Generation)** -- retrieve relevant context before
  generating a response

The `aim_vectors` module provides a unified interface for embedding generation across
multiple providers.

## Usage

### Register to AI provider

In order to have access to an AI provider API, register and get an API Key.

**WARNING**: API Keys need to be be kept secret.

- Anthropic/Claude:
  - https://platform.claude.com/docs/en/get-started
- OpenAI/GPT:
  - https://developers.openai.com/api/docs/quickstart
- Google/Gemini:
  - https://ai.google.dev/gemini-api/docs/quickstart
- Mistral:
  - https://docs.mistral.ai/getting-started/quickstart

Define the following environment variables, according to the AI provider:

- Anthropic/Claude:
  - ANTHROPIC_API_KEY: The API Key
- OpenAI/GPT:
  - OPENAI_API_KEY: The API Key
- Google/Gemini:
  - GOOGLE_PROJECT_ID: The Google project ID
  - GEMINI_API_KEY: The API Key
- Mistral:
  - MISTRAL_API_KEY: The API Key
- VoyageAI:
  - VOYAGE_API_KEY: The API Key

### Compilation

```bash
make clean all
```

### Quick Test

After building the 42m modules:

```
$ export ANTHROPIC_API_KEY="sk-ant-..."

$ export FGLLDPATH=<repository-root-dir>

$ fglrun com/fourjs/ai/fgl_ai_sdk/tests/test_anthropic
The exact geographic coordinates of London are:

- **Latitude: 51.5074° N**
- **Longitude: -0.1278° W** (or 0.1278° E)

These coordinates point to the city center of London, England.
The negative longitude value indicates it is located west of
the Prime Meridian (0° longitude), which runs through Greenwich
in London.
```

## Programming API

### Example: Text completion with Anthropic Claude

```4gl
IMPORT FGL com.fourjs.ai.fgl_ai_sdk.aim_anthropic

MAIN

    DEFINE client aim_anthropic.t_client
    DEFINE request aim_anthropic.t_message_request
    DEFINE response aim_anthropic.t_response
    DEFINE x, tx, s INTEGER

    CALL aim_anthropic.initialize()

    CALL client.set_defaults("claude-haiku-4-5")
    LET client.connection.secret_key = "...." -- API Key

    CALL request.set_defaults(client)
    CALL request.set_system_message("You are a Math teacher.")
    LET x = request.append_user_message("Answer with precise instructions.")
    LET x = request.append_user_message("How to compute the area of a circle?")
    LET s = client.create_message(request,response)
    IF s == 0 THEN
        DISPLAY response.get_content_text(1)
    ELSE
        DISPLAY aim_anthropic.get_error_message(s)
        DISPLAY "HTTP post status: ", aim_anthropic.get_last_http_post_status()
        DISPLAY "HTTP post description : ", aim_anthropic.get_last_http_post_description()
    END IF

    CALL aim_anthropic.cleanup()

END MAIN
```

### Example: Text embedding generation with Gemini Embedding

```4gl
IMPORT FGL com.fourjs.ai.fgl_ai_sdk.aim_vectors

MAIN

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

    CALL aim_vectors.initialize()

    CALL client.set_defaults("gemini","gemini-embedding-001")
    LET client.connection.secret_key = "...." -- API Key

    CALL request.set_defaults(client,NULL)

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
```

### Example: Text completion using tools with Google Gemini
```4gl
IMPORT FGL com.fourjs.ai.fgl_ai_sdk.aim_gemini

MAIN

    DEFINE client aim_gemini.t_client
    DEFINE request aim_gemini.t_text_request
    DEFINE response aim_gemini.t_text_response
    DEFINE x, tx, s INTEGER

    CALL aim_gemini.initialize()

    CALL client.set_defaults("gemini-3-flash-preview")
    LET client.connection.secret_key = "...." -- API Key

    CALL request.set_defaults(client)
    VAR mycallback aim_gemini.t_tool_function_dispatcher = FUNCTION exec_tools
    CALL request.set_system_instruction("You are a Math teacher.")
    LET x = request.append_user_content("Use provided tools to generate the result.")

    VAR tps1 aim_gemini.t_tool_signature_params = [
          (name:"operand_1", type:"number", description:"First operand.", required: TRUE ),
          (name:"operand_2", type:"number", description:"Second operand.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("multiplication","Multiplies two numbers.",tps1)

    VAR tps2 aim_gemini.t_tool_signature_params = [
          (name:"dividend", type:"number", description:"The dividend operand.", required: TRUE ),
          (name:"divisor", type:"number", description:"The divisor operand.", required: TRUE )
        ]
    LET tx = request.append_tool_definition("integer_division",
            "Divides two integer numbers and produces a quotient and remainder.",tps2)

    --LET x = request.append_user_content("How much is 25 multiplied by 5?")
    LET x = request.append_user_content("What is the quotient and remainder of 13 divided by 5?")

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

    CALL aim_gemini.cleanup()

END MAIN

PRIVATE FUNCTION exec_tools(
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
    OTHERWISE RETURN -1
    END CASE
END FUNCTION
```

## TODO:
- none

## Bug fixes:
- none
