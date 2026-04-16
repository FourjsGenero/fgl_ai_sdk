# FGL SDK for Artificial Intelligence APIs

## Description

This project contains a set of Genero BDL modules to interface with AI provider APIs,
organized as the `com.fourjs.aim` package.

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

## Supported AI providers and services

Supported AI Providers:
- Anthropic/Claude
- OpenAI/GPT
- Google/Gemini
- Mistral
- Ollama

Supported AI services:

- Text Generation
  - Anthropic/Claude with `aim_anthropic.4gl`
  - OpenAI/GPT with `aim_openai.4gl`
  - Google/Gemini with `aim_gemini.4gl`
  - Mistral with `aim_mistral.4gl`
  - Ollama with `aim_ollama.4gl`

- Text Embedding with `aim_vectors.4gl`
  - OpenAI text embedding
  - Gemini text embedding
  - Mistral text embedding
  - VoyageAI text embedding

## Project structure

```
fgl_ai_sdk/
|-- aim_common.4gl          -- Shared utilities, HTTP infrastructure, common types
|-- aim_anthropic.4gl       -- Anthropic/Claude API
|-- aim_gemini.4gl          -- Google/Gemini API
|-- aim_openai.4gl          -- OpenAI/GPT API
|-- aim_mistral.4gl         -- Mistral API
|-- aim_ollama.4gl          -- Ollama API
|-- aim_vectors.4gl         -- Text embedding (multi-provider)
|-- test_common.4gl         -- Shared test utilities (arg parsing, usage, tool callbacks)
|-- test_anthropic.4gl      -- Test program for Anthropic
|-- test_gemini.4gl         -- Test program for Gemini
|-- test_openai.4gl         -- Test program for OpenAI
|-- test_mistral.4gl        -- Test program for Mistral
|-- test_ollama.4gl         -- Test program for Ollama
|-- test_vectors.4gl        -- Test program for text embeddings
|-- Makefile
|-- com/fourjs/aim/         -- Compiled package modules (.42m)
```

All modules belong to the `com.fourjs.aim` package. The compiled `.42m` files are
placed in `com/fourjs/aim/` by the build.

## License

This source code is under [MIT license](./LICENSE)

## Prerequisites

* Latest Genero version
* GNU Make

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

### API key configuration

API keys can be configured in two ways. The FGLPROFILE entry is checked first;
if not found, the environment variable is used as a fallback.

| Provider   | FGLPROFILE entry        | Environment variable   |
|------------|-------------------------|------------------------|
| Anthropic  | `aim.apikey.anthropic`  | `ANTHROPIC_API_KEY`    |
| OpenAI     | `aim.apikey.openai`     | `OPENAI_API_KEY`       |
| Gemini     | `aim.apikey.gemini`     | `GEMINI_API_KEY`       |
| Mistral    | `aim.apikey.mistral`    | `MISTRAL_API_KEY`      |
| VoyageAI   | `aim.apikey.voyageai`   | `VOYAGE_API_KEY`       |

Ollama does not require an API key for local instances.

Additional environment variables for specific providers:

- Google/Gemini:
  - `GOOGLE_PROJECT_ID`: The Google project ID
- OpenAI/GPT:
  - `OPENAI_ORGANIZATION_ID`: The OpenAI organization ID (optional)
  - `OPENAI_PROJECT_ID`: The OpenAI project ID (optional)

**FGLPROFILE example:**

```
aim.apikey.anthropic = "sk-ant-..."
aim.apikey.openai    = "sk-..."
aim.apikey.gemini    = "AI..."
```

### Compilation

```bash
make clean all
```

This compiles all modules (libraries and test programs) into `com/fourjs/aim/`.

### Running the test programs

All test programs support a common command-line interface:

```
fglrun com/fourjs/aim/<test_program> [OPTIONS] [key=value ...]
```

**Options:**
- `--default` - Run with default hard-coded parameters
- `--help` - Display usage with all available parameters, defaults, and
  required environment variables / FGLPROFILE entries
- No arguments displays the usage message

**Examples:**

```bash
# Show usage, available parameters, and environment setup for Anthropic
$ fglrun com/fourjs/aim/test_anthropic.42m --help

# Run with defaults (tool calling mode)
$ export ANTHROPIC_API_KEY="sk-ant-..."
$ fglrun com/fourjs/aim/test_anthropic.42m --default

# Custom parameters
$ fglrun com/fourjs/aim/test_anthropic.42m model=claude-sonnet-4-5 prompt="What is 2+2?" tools=false

# Override just the prompt (other params keep their defaults)
$ fglrun com/fourjs/aim/test_anthropic.42m prompt="How much is 25 multiplied by 5?"
```

Each test program documents its own parameters via `--help`. Common parameters
across text generation providers include:

| Parameter     | Description                       |
|---------------|-----------------------------------|
| `model`       | Model name                        |
| `system`      | System message / instructions     |
| `prompt`      | User prompt                       |
| `max_tokens`  | Maximum output tokens             |
| `temperature` | Sampling temperature (0.0-1.0)    |
| `top_p`       | Nucleus sampling threshold        |
| `tools`       | Enable tool calling (true/false)  |

Some providers support additional parameters (e.g., `top_k`, `seed`,
`frequency_penalty`, `presence_penalty`). The Ollama test exposes `base_url`
and `tcp_port` for connecting to custom server instances. The vectors test
accepts `provider`, `model`, `dimensions`, and `source` parameters.

**Make targets:**

Make targets run with `--default` when no `ARGS` are specified. Pass the `ARGS`
variable to override:

```bash
# Run with defaults
make test-anthropic

# Pass custom arguments
make test-anthropic ARGS="prompt='What is 2+2?' tools=false"

# Show help
make test-anthropic ARGS="--help"
```

Available targets:

```bash
make test-anthropic
make test-gemini
make test-openai
make test-mistral
make test-ollama
make test-vectors
```

## Programming API

### Importing the package

Programs that use the SDK must import the modules they need from the `com.fourjs.aim`
package:

```4gl
IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_anthropic
```

Shared functions such as `initialize()`, `cleanup()`, and `get_error_message()` are
in the `aim_common` module. Provider-specific types and functions are in the respective
provider module.

### Example: Text completion with Anthropic Claude

```4gl
IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_anthropic

FUNCTION main()
    DEFINE client aim_anthropic.t_client
    DEFINE request aim_anthropic.t_message_request
    DEFINE response aim_anthropic.t_response
    DEFINE x, s INTEGER

    CALL aim_common.initialize()

    CALL client.set_defaults("claude-haiku-4-5")

    CALL request.set_defaults(client)
    CALL request.set_system_message("You are a Math teacher.")
    LET x = request.append_user_message("Answer with precise instructions.")
    LET x = request.append_user_message("How to compute the area of a circle?")
    LET s = client.create_message(request,response)
    IF s == 0 THEN
       DISPLAY response.get_content_text(1)
    ELSE
       DISPLAY aim_common.get_error_message(s)
       DISPLAY "HTTP post status: ", aim_common.get_last_http_post_status()
       DISPLAY "HTTP post description : ", aim_common.get_last_http_post_description()
    END IF

    CALL aim_common.cleanup()
END FUNCTION
```

### Example: Text embedding generation with Gemini Embedding

```4gl
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
```

## TODO:
- none

## Bug fixes:
- none
