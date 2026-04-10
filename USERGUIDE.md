# FGL AI SDK User Guide

## Overview

The FGL AI SDK package (`com.fourjs.aim`) provides a Genero BDL library for integrating
with AI provider APIs. It supports text generation (chat completions) and text embedding
across multiple providers through a consistent module structure.

| Service | Module | Provider |
|---------|--------|----------|
| **Text Generation** | `aim_anthropic` | Anthropic / Claude |
| **Text Generation** | `aim_openai` | OpenAI / GPT |
| **Text Generation** | `aim_gemini` | Google / Gemini |
| **Text Generation** | `aim_mistral` | Mistral |
| **Text Generation** | `aim_ollama` | Ollama (local) |
| **Text Embedding** | `aim_vectors` | OpenAI, Gemini, Mistral, VoyageAI |
| **Shared Utilities** | `aim_common` | All providers |

Each provider module follows the same pattern: create a client, configure a request,
send it, and process the response. The `aim_common` module provides shared lifecycle
management, error handling, HTTP infrastructure, and common types used across all
providers.

For detailed API documentation and code examples, see the [README](README.md).

---

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

---

## Installation

### Prerequisites

- Genero BDL 6.x or later
- An API key from at least one supported AI provider

### Using the Genero Package Manager (fglpkg)

#### Step 1: Install fglpkg

Download the `fglpkg` binary for your platform from
[GitHub Releases](https://github.com/4js-mikefolcher/fglpkg/releases) and place it
in a directory on your `PATH`:

```bash
# macOS/Linux example
sudo cp fglpkg-darwin-arm64 /usr/local/bin/fglpkg
sudo chmod +x /usr/local/bin/fglpkg
```

#### Step 2: Understand local vs. global installation

`fglpkg` supports two installation scopes:

| Scope | Packages stored in | Environment command | Best for |
|-------|-------------------|---------------------|----------|
| **Local** (`--local`) | `.fglpkg/` inside the project directory | `eval "$(fglpkg env)"` | Development workstations where multiple Genero versions may coexist |
| **Global** (`--global`) | `~/.fglpkg/` (user home) | `eval "$(fglpkg env --global)"` | CI/CD pipelines and build servers with a single Genero version |

**Local installation** is recommended for individual development environments. Because
compiled BDL modules (`.42m` files) are tied to a specific Genero major version,
keeping packages local to each project avoids conflicts when different projects target
different Genero versions.

**Global installation** is better suited for CI/CD pipelines and build servers where
a single Genero version is installed.

#### Step 3: Configure your shell environment

Add one of the following lines to your shell profile (`~/.bashrc`, `~/.zshrc`, or
equivalent) so that installed packages are available to Genero at compile and runtime:

**For local (development) installation:**

```bash
# Run from within your project directory
eval "$(fglpkg env)"

# If using GST, run this command and copy the output to put into your project environment variables
fglpkg env --gst
```

**For global (CI/CD) installation:**

```bash
# Add to shell profile for build servers
eval "$(fglpkg env --global)"
```

Both commands export the `FGLLDPATH` environment variable with paths to the installed
BDL packages. Reload your shell or run `source ~/.bashrc` (or `source ~/.zshrc`) after
making changes.

#### Step 4: Add fgl_ai_sdk as a dependency

If your project does not already have a `fglpkg.json` file, create one by running:

```bash
cd /path/to/your/project
fglpkg init
```

Then add `fgl_ai_sdk` as a dependency. You can do this by running:

```bash
# Local install (default when inside a project directory)
fglpkg install fgl_ai_sdk

# Or explicitly global for CI/CD
fglpkg install --global fgl_ai_sdk
```

Or by manually editing your project's `fglpkg.json` to include the dependency:

```json
{
  "name": "my-project",
  "version": "1.0.0",
  "dependencies": {
    "fgl": {
      "fgl_ai_sdk": "^1.0.0"
    }
  }
}
```

Then run:

```bash
fglpkg install
```

#### Step 5: Verify the installation

Confirm the package is installed:

```bash
fglpkg list
```

You should see `fgl_ai_sdk` listed with its version number.

### Manual Installation

If you are not using `fglpkg`, you can install the package manually:

1. Clone or download the repository
2. Run `make clean all` to compile
3. Add the project root directory to your `FGLLDPATH` environment variable so that
   Genero can resolve `com/fourjs/aim/*.42m`

---

## API Key Configuration

Each AI provider requires an API key. The SDK checks for keys in two places, in order:

1. **FGLPROFILE entry** (checked first): `aim.apikey.<provider>`
2. **Environment variable** (fallback): provider-specific variable name

| Provider | FGLPROFILE entry | Environment variable |
|----------|-----------------|---------------------|
| Anthropic | `aim.apikey.anthropic` | `ANTHROPIC_API_KEY` |
| OpenAI | `aim.apikey.openai` | `OPENAI_API_KEY` |
| Gemini | `aim.apikey.gemini` | `GEMINI_API_KEY` |
| Mistral | `aim.apikey.mistral` | `MISTRAL_API_KEY` |
| VoyageAI | `aim.apikey.voyageai` | `VOYAGE_API_KEY` |

Ollama does not require an API key for local instances.

**FGLPROFILE example:**

```
aim.apikey.anthropic = "sk-ant-..."
aim.apikey.openai    = "sk-..."
aim.apikey.gemini    = "AI..."
```

---

## Quick Start

### Importing the Package

Programs that use the SDK must import the modules they need from the `com.fourjs.aim`
package:

```4gl
IMPORT FGL com.fourjs.aim.aim_common
IMPORT FGL com.fourjs.aim.aim_anthropic
```

The `aim_common` module provides shared functions:

| Function | Description |
|----------|-------------|
| `aim_common.initialize()` | Initialize the SDK (call once at startup) |
| `aim_common.cleanup()` | Clean up resources (call before exit) |
| `aim_common.get_error_message(err_num)` | Get a human-readable error message |
| `aim_common.get_last_http_post_status()` | Get the HTTP status code of the last failed request |
| `aim_common.get_last_http_post_description()` | Get the HTTP status description of the last failed request |

### Basic Text Generation

The general pattern for text generation is the same across all providers:

1. Initialize the SDK with `aim_common.initialize()`
2. Create and configure a client with `client.set_defaults(model_name)`
3. Create a request, set a system message, and append user messages
4. Send the request and process the response
5. Clean up with `aim_common.cleanup()`

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
    CALL request.set_system_message("You are a helpful assistant.")
    LET x = request.append_user_message("What is the capital of France?")

    LET s = client.create_message(request, response)
    IF s == 0 THEN
        DISPLAY response.get_content_text(1)
    ELSE
        DISPLAY aim_common.get_error_message(s)
    END IF

    CALL aim_common.cleanup()
END FUNCTION
```

### Tool Use (Function Calling)

The SDK supports tool use for providers that offer it. You define tool signatures,
and the model can request tool execution during a conversation:

1. Define tool parameters using `aim_common.t_tool_signature_params`
2. Register tools on the request with `request.append_tool_definition()`
3. Send the request -- if the model wants to call a tool, the return code is `1`
4. Loop with `client.continue_message()` (or the provider equivalent), passing a
   callback function that executes the tool and returns results
5. The loop continues until the model produces a final text response (return code `0`)

```4gl
-- Define a tool callback function
FUNCTION my_tools(
    name STRING,
    params DICTIONARY OF STRING,
    results DICTIONARY OF STRING
) RETURNS INTEGER
    CASE name
    WHEN "get_weather"
        LET results["temperature"] = "22"
        LET results["conditions"] = "sunny"
        RETURN 0
    OTHERWISE
        RETURN -1
    END CASE
END FUNCTION
```

### Error Handling

All request functions return an integer status code:

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Tool calls required (continue the conversation) |
| `-101` | No model provided |
| `-102` | No secret key provided |
| `-103` | No project ID provided |
| `-201` | HTTP POST error (non-200 status) |
| `-202` | HTTP POST request error (network/connection failure) |
| `-301` | Could not parse response as JSON |
| `-401` | Could not convert JSON response to FGL type |
| `-501` | Tool function execution failed |
| `-502` | Failed to parse tool call arguments |

Use `aim_common.get_error_message(s)` to convert a status code to a readable message.
For HTTP errors (`-201`), use `aim_common.get_last_http_post_status()` and
`aim_common.get_last_http_post_description()` for details.

---

## Provider-Specific Notes

### Anthropic / Claude

- Import: `IMPORT FGL com.fourjs.aim.aim_anthropic`
- Types: `t_client`, `t_message_request`, `t_response`
- Create: `client.create_message(request, response)`
- Continue (tools): `client.continue_message(request, response, callback)`
- System message: `request.set_system_message(content)`

### OpenAI / GPT

- Import: `IMPORT FGL com.fourjs.aim.aim_openai`
- Types: `t_client`, `t_response_request`, `t_response`
- Create: `client.create_response(request, response)`
- Continue (tools): `client.continue_response(request, response, callback)`
- System message: `request.set_instructions(content)`
- Supports response deletion: `client.delete_response(response)`

### Google / Gemini

- Import: `IMPORT FGL com.fourjs.aim.aim_gemini`
- Types: `t_client`, `t_text_request`, `t_text_response`
- Create: `client.create_response(request, response)`
- Continue (tools): `client.continue_response(request, response, callback)`
- System message: `request.set_system_instruction(content)`
- Supports multi-part system instructions

### Mistral

- Import: `IMPORT FGL com.fourjs.aim.aim_mistral`
- Types: `t_client`, `t_chat_request`, `t_chat_response`
- Create: `client.create_chat_completion(request, response)`
- Continue (tools): `client.continue_chat_completion(request, response, callback)`
- System message: `request.set_system_message(content)`
- Codestral models automatically use the `codestral.mistral.ai` endpoint

### Ollama

- Import: `IMPORT FGL com.fourjs.aim.aim_ollama`
- Types: `t_client`, `t_response_request`, `t_response`
- Create: `client.create_response(request, response)`
- System message: `request.set_system_message(content)`
- Prompt: `request.set_prompt_message(content)`
- No API key required for local instances
- Default endpoint: `localhost:11434`
- Does not support tool use

### Text Embeddings

- Import: `IMPORT FGL com.fourjs.aim.aim_vectors`
- Types: `t_client`, `t_text_embedding_request`, `t_text_embedding_response`
- Client takes a provider and model: `client.set_defaults("gemini", "gemini-embedding-001")`
- Send: `client.send_text_embedding_request(request, response)`
- Get vector: `response.get_vector()` returns a JSON array string of floats
- Supported providers: `openai`, `gemini`, `mistral`, `voyageai`, `anthropic`

---

## Further Reading

For the complete API reference, code examples including tool use, and project
development details, see the [README](README.md).
