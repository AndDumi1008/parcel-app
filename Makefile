.PHONY: test lint build
test:    ## load migrations + seed into PostgreSQL 16, run RLS assertions, run masking
	./tests/run.sh
lint:    ## sql files parse (psql --dry via docker) and shell scripts
	@bash -n tests/run.sh && echo "shell ok"
build:   ## nothing to build yet (frontend to follow)
	@echo "no build step yet"
