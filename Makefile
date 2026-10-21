.PHONY: test lint build web-build web-deploy web-rollback web-status web-test
test:    ## load migrations + seed into PostgreSQL 16, run RLS assertions, run masking
	./tests/run.sh
lint:    ## sql files parse (psql --dry via docker) and shell scripts
	@for f in tests/run.sh tests/web_test.sh scripts/web-remote.sh; do bash -n "$$f"; done
	@for f in deploy/web/web-deploy/web-deploy-shell deploy/web/web-deploy/entrypoint.sh; do sh -n "$$f"; done
	@echo "shell ok"
build:   ## the frontend build is web-build
	@echo "no build step besides web-build"

# Frontend (AI-Gov-Layer docs/07 §10.6, PD-44/PD-45). The PaaS workflows call these with the environment secret
# WEB_DEPLOY_KEY; each prints the digest now served.
web-build:    ## static export into out/ (the placeholder page until the Next.js frontend lands)
	rm -rf out && mkdir out && cp -R web/placeholder/. out/
web-deploy:   ## ENV= ARTIFACT= DIGEST=sha256:… BACKEND_URL=https://…
	@scripts/web-remote.sh deploy '$(ENV)' '$(ARTIFACT)' '$(DIGEST)' '$(BACKEND_URL)'
web-rollback: ## ENV=; back to the previous release digest
	@scripts/web-remote.sh rollback '$(ENV)'
web-status:   ## ENV=; the release digest now served
	@scripts/web-remote.sh status '$(ENV)'
web-test:     ## throw-away web + web-deploy pair: deploy, rollback and the refusals
	./tests/web_test.sh
