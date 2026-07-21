TESTS=\
 test_anthropic.42m\
 test_gemini.42m\
 test_openai.42m\
 test_mistral.42m\
 test_ollama.42m\
 test_vectors.42m

all: $(TESTS)

test_anthropic.42m: test_anthropic.4gl
	fglcomp -Wall -M test_anthropic.4gl

test_gemini.42m: test_gemini.4gl
	fglcomp -Wall -M test_gemini.4gl

test_openai.42m: test_openai.4gl
	fglcomp -Wall -M test_openai.4gl

test_mistral.42m: test_mistral.4gl
	fglcomp -Wall -M test_mistral.4gl

test_ollama.42m: test_ollama.4gl
	fglcomp -Wall -M test_ollama.4gl

test_vectors.42m: test_vectors.4gl
	fglcomp -Wall -M test_vectors.4gl

clean::
	rm -f *.42?
