MODULES=\
 aim_anthropic.42m\
 aim_gemini.42m\
 aim_openai.42m\
 aim_mistral.42m\
 aim_ollama.42m\
 aim_vectors.42m

all: $(MODULES)

aim_anthropic.42m: aim_anthropic.4gl
	fglcomp -Wall -M aim_anthropic.4gl

aim_gemini.42m: aim_gemini.4gl
	fglcomp -Wall -M aim_gemini.4gl

aim_openai.42m: aim_openai.4gl
	fglcomp -Wall -M aim_openai.4gl

aim_mistral.42m: aim_mistral.4gl
	fglcomp -Wall -M aim_mistral.4gl

aim_ollama.42m: aim_ollama.4gl
	fglcomp -Wall -M aim_ollama.4gl

aim_vectors.42m: aim_vectors.4gl
	fglcomp -Wall -M aim_vectors.4gl

clean::
	rm -f *.42m *.42f
