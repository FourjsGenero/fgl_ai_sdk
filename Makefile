PKGDIR=./com/fourjs/ai/fgl_ai_sdk
TESTDIR=$(PKGDIR)/tests

MODULES=\
 $(PKGDIR)/aim_anthropic.42m\
 $(PKGDIR)/aim_gemini.42m\
 $(PKGDIR)/aim_openai.42m\
 $(PKGDIR)/aim_mistral.42m\
 $(PKGDIR)/aim_ollama.42m\
 $(PKGDIR)/aim_vectors.42m

TESTS=\
 $(TESTDIR)/test_anthropic.42m\
 $(TESTDIR)/test_gemini.42m\
 $(TESTDIR)/test_openai.42m\
 $(TESTDIR)/test_mistral.42m\
 $(TESTDIR)/test_ollama.42m\
 $(TESTDIR)/test_vectors.42m

all: $(MODULES) $(TESTS)

$(PKGDIR)/aim_anthropic.42m: $(PKGDIR)/aim_anthropic.4gl
	fglcomp -Wall -M $(PKGDIR)/aim_anthropic.4gl
$(TESTDIR)/test_anthropic.42m: $(TESTDIR)/test_anthropic.4gl $(PKGDIR)/aim_anthropic.42m
	fglcomp -Wall -M $(TESTDIR)/test_anthropic.4gl

$(PKGDIR)/aim_gemini.42m: $(PKGDIR)/aim_gemini.4gl
	fglcomp -Wall -M $(PKGDIR)/aim_gemini.4gl
$(TESTDIR)/test_gemini.42m: $(TESTDIR)/test_gemini.4gl $(PKGDIR)/aim_gemini.42m
	fglcomp -Wall -M $(TESTDIR)/test_gemini.4gl

$(PKGDIR)/aim_openai.42m: $(PKGDIR)/aim_openai.4gl
	fglcomp -Wall -M $(PKGDIR)/aim_openai.4gl
$(TESTDIR)/test_openai.42m: $(TESTDIR)/test_openai.4gl $(PKGDIR)/aim_openai.42m
	fglcomp -Wall -M $(TESTDIR)/test_openai.4gl

$(PKGDIR)/aim_mistral.42m: $(PKGDIR)/aim_mistral.4gl
	fglcomp -Wall -M $(PKGDIR)/aim_mistral.4gl
$(TESTDIR)/test_mistral.42m: $(TESTDIR)/test_mistral.4gl $(PKGDIR)/aim_mistral.42m
	fglcomp -Wall -M $(TESTDIR)/test_mistral.4gl

$(PKGDIR)/aim_ollama.42m: $(PKGDIR)/aim_ollama.4gl
	fglcomp -Wall -M $(PKGDIR)/aim_ollama.4gl
$(TESTDIR)/test_ollama.42m: $(TESTDIR)/test_ollama.4gl $(PKGDIR)/aim_ollama.42m
	fglcomp -Wall -M $(TESTDIR)/test_ollama.4gl

$(PKGDIR)/aim_vectors.42m: $(PKGDIR)/aim_vectors.4gl
	fglcomp -Wall -M $(PKGDIR)/aim_vectors.4gl
$(TESTDIR)/test_vectors.42m: $(TESTDIR)/test_vectors.4gl $(PKGDIR)/aim_vectors.42m
	fglcomp -Wall -M $(TESTDIR)/test_vectors.4gl

clean::
	rm -f $(PKGDIR)/*.42?
	rm -f $(TESTDIR)/*.42?
