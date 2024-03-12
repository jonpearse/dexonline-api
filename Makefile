default: run
	
setup:
	@brew bundle --no-upgrade --no-lock
	@bundle

run:
	watchexec -r -e rb,jbuilder 'puma -s -p 3000 config.ru'