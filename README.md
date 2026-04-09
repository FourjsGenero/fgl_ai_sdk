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

## Supported AIs

Supported AI Providers:
- Anthropic with `aim_anthropic.4gl`
- OpenAI with `aim_openai.4gl`
- Gemini with `aim_gemini.4gl`
- Mistral with `aim_mistral.4gl`

Supported AI services:
- Text Generation / Conversations / Chat
- Text Embedding

## License

This source code is under [MIT license](./LICENSE)

## Prerequisites

* Latest Genero version
* GNU Make

## Compilation from command line

1. make clean all

## Run in direct mode with GDC

1. make run

## Programming API

See [Genero AI API SDK documentation](http://htmlpreview.github.io/?github.com/FourjsGenero/fgl_ai_sdk/raw/master/docs/xxx.html)

## TODO:
- none

## Bug fixes:
- none
