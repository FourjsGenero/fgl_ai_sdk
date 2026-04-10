# FGL SDK for Artificial Intelligence APIs

## Description

This project contains a set of Genero BDL modules to interface with AI providers APIs.

## Disclaimer

This source code is provided "as is" and "with all faults." The authors make no guarantees
or warranties of any kind concerning the safety, reliability, or suitability of the software
for any main or particular purpose.

This SDK is a connector and requires a third-party AI provider, a compatible Large Language
Model (LLM), and a valid API key. Users are solely responsible for any costs, usage limits,
and terms of service associated with their chosen AI provider.

Using this software involves transmitting data to third-party services. Before proceeding,
you must evaluate the security, privacy, and confidentiality implications of sharing sensitive
information with these providers. The authors are not liable for any data breaches or misuse
of information by third-party AI entities.

## Supported AI providers and services

Supported AI Providers:
- Anthropic/Claude
- OpenAI/GPT
- Google/Gemini
- Mistral
- Ollama

Supported AI services:

- Text Generation / Conversations / Chat
  - Anthropic/Claude with `aim_anthropic.4gl`
  - OpenAI/GPT with `aim_openai.4gl`
  - Google/Gemini with `aim_gemini.4gl`
  - Mistral with `aim_mistral.4gl`
  - Ollama with `aim_ollama.4gl`

- Text Embedding with `aim_vector.4gl`
  - OpenAI text embedding
  - Gemini text embedding
  - Mistral text embedding
  - VoyageAI text embedding

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

### Compilation

```bash
make clean all
```

### Quick Test

After compilation, you can directly run one of the aim_* modules:
Each module includes a `main()` function that does some tests.

```
$ export ANTHROPIC_API_KEY="sk-ant-..."

$ fglrun aim_anthropic.42m
The exact geographic coordinates of London are:

- **Latitude: 51.5074° N**
- **Longitude: -0.1278° W** (or 0.1278° E)

These coordinates point to the city center of London, England.
The negative longitude value indicates it is located west of
the Prime Meridian (0° longitude), which runs through Greenwich
in London.
```

## Programming API

### Example: Text completion with Anthropic

```4gl
IMPORT FGL aim_anthropic

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
```

### Example: Text embedding generation with Anthropic

```4gl
IMPORT FGL aim_vectors

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
```

## TODO:
- none

## Bug fixes:
- none
