EXE=_build/default/mgoc.exe
TEST ?= tests/test.go      #fichier teste par defaut

all: $(EXE)

$(EXE): *.ml*
	dune build @all

test: $(EXE)
	-./$(EXE) --parse-only $(TEST)

.PHONY: clean
clean:
	dune clean
	rm -f *~ tests/*~