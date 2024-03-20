default: run

setup:
	@brew bundle --no-upgrade --no-lock
	@bundle

run:
	watchexec -r -e rb,jbuilder 'puma -s -p 3000 config.ru'

build:
	docker build --platform linux/amd64 -t dexonline-api .
	docker tag dexonline-api:latest $(REPO_HOST)/dexonline-api:latest
	docker push $(REPO_HOST)/dexonline-api:latest
