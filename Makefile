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

COMMON=test_common.42m

TESTS=\
 test_anthropic.42m\
 test_gemini.42m\
 test_openai.42m\
 test_mistral.42m\
 test_ollama.42m\
 test_vectors.42m

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

test_common.42m: test_common.4gl $(PKGDIR)/aim_common.42m
	fglcomp -Wall -M test_common.4gl

test_anthropic.42m: test_anthropic.4gl $(PKGDIR)/aim_anthropic.42m $(COMMON)
	fglcomp -Wall -M test_anthropic.4gl

test_gemini.42m: test_gemini.4gl $(PKGDIR)/aim_gemini.42m $(COMMON)
	fglcomp -Wall -M test_gemini.4gl

test_openai.42m: test_openai.4gl $(PKGDIR)/aim_openai.42m $(COMMON)
	fglcomp -Wall -M test_openai.4gl

test_mistral.42m: test_mistral.4gl $(PKGDIR)/aim_mistral.42m $(COMMON)
	fglcomp -Wall -M test_mistral.4gl

test_ollama.42m: test_ollama.4gl $(PKGDIR)/aim_ollama.42m $(COMMON)
	fglcomp -Wall -M test_ollama.4gl

test_vectors.42m: test_vectors.4gl $(PKGDIR)/aim_vectors.42m $(COMMON)
	fglcomp -Wall -M test_vectors.4gl

clean::
	rm -rf com *.42m *.42f

test-anthropic: test_anthropic.42m
	fglrun test_anthropic.42m --default

test-gemini: test_gemini.42m
	fglrun test_gemini.42m --default

test-openai: test_openai.42m
	fglrun test_openai.42m --default

test-mistral: test_mistral.42m
	fglrun test_mistral.42m --default

test-ollama: test_ollama.42m
	fglrun test_ollama.42m --default

test-vectors: test_vectors.42m
	fglrun test_vectors.42m --default
