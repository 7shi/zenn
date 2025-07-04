all:

preview:
	@echo -n open:
	@ip address | grep "scope global eth0" | awk '{print $2}' | cut -d'/' -f1 | sed 's/$$/:8000/'
	npx zenn preview

new:
	@echo "use: npx zenn new:article --slug xxx"

commit:
	@bash commit.sh

push: commit
	git log -n 1
	@bash confirm.sh "このままpushしますか?" && git push
