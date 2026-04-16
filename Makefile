TOP=../../..

PKGDIR=com/fourjs/aim

LIBS=\
 $(PKGDIR)/aim_common.42m\
 $(PKGDIR)/aim_anthropic.42m\
 $(PKGDIR)/aim_gemini.42m\
 $(PKGDIR)/aim_openai.42m\
 $(PKGDIR)/aim_mistral.42m\
 $(PKGDIR)/aim_ollama.42m\
 $(PKGDIR)/aim_vectors.42m

COMMON=$(PKGDIR)/test_common.42m

TESTS=\
 $(PKGDIR)/test_anthropic.42m\
 $(PKGDIR)/test_gemini.42m\
 $(PKGDIR)/test_openai.42m\
 $(PKGDIR)/test_mistral.42m\
 $(PKGDIR)/test_ollama.42m\
 $(PKGDIR)/test_vectors.42m

all: $(LIBS) $(COMMON) $(TESTS)

$(PKGDIR)/aim_common.42m: aim_common.4gl
	fglcomp -Wall -M --output-dir . aim_common.4gl

$(PKGDIR)/aim_anthropic.42m: aim_anthropic.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M --output-dir . aim_anthropic.4gl

$(PKGDIR)/aim_gemini.42m: aim_gemini.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M --output-dir . aim_gemini.4gl

$(PKGDIR)/aim_openai.42m: aim_openai.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M --output-dir . aim_openai.4gl

$(PKGDIR)/aim_mistral.42m: aim_mistral.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M --output-dir . aim_mistral.4gl

$(PKGDIR)/aim_ollama.42m: aim_ollama.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M --output-dir . aim_ollama.4gl

$(PKGDIR)/aim_vectors.42m: aim_vectors.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M --output-dir . aim_vectors.4gl

$(PKGDIR)/test_common.42m: test_common.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M --output-dir . test_common.4gl

$(PKGDIR)/test_anthropic.42m: test_anthropic.4gl $(PKGDIR)/aim_anthropic.42m $(COMMON)
	fglcomp -Wall -M --output-dir . test_anthropic.4gl

$(PKGDIR)/test_gemini.42m: test_gemini.4gl $(PKGDIR)/aim_gemini.42m $(COMMON)
	fglcomp -Wall -M --output-dir . test_gemini.4gl

$(PKGDIR)/test_openai.42m: test_openai.4gl $(PKGDIR)/aim_openai.42m $(COMMON)
	fglcomp -Wall -M --output-dir . test_openai.4gl

$(PKGDIR)/test_mistral.42m: test_mistral.4gl $(PKGDIR)/aim_mistral.42m $(COMMON)
	fglcomp -Wall -M --output-dir . test_mistral.4gl

$(PKGDIR)/test_ollama.42m: test_ollama.4gl $(PKGDIR)/aim_ollama.42m $(COMMON)
	fglcomp -Wall -M --output-dir . test_ollama.4gl

$(PKGDIR)/test_vectors.42m: test_vectors.4gl $(PKGDIR)/aim_vectors.42m $(COMMON)
	fglcomp -Wall -M --output-dir . test_vectors.4gl

clean::
	rm -rf com *.42m *.42f

ARGS ?= --default

test-anthropic: $(PKGDIR)/test_anthropic.42m
	fglrun $(PKGDIR)/test_anthropic.42m $(ARGS)

test-gemini: $(PKGDIR)/test_gemini.42m
	fglrun $(PKGDIR)/test_gemini.42m $(ARGS)

test-openai: $(PKGDIR)/test_openai.42m
	fglrun $(PKGDIR)/test_openai.42m $(ARGS)

test-mistral: $(PKGDIR)/test_mistral.42m
	fglrun $(PKGDIR)/test_mistral.42m $(ARGS)

test-ollama: $(PKGDIR)/test_ollama.42m
	fglrun $(PKGDIR)/test_ollama.42m $(ARGS)

test-vectors: $(PKGDIR)/test_vectors.42m
	fglrun $(PKGDIR)/test_vectors.42m $(ARGS)
