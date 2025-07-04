all:

preview:
	@echo -n open:
	@ip address | grep "scope global eth0" | awk '{print $2}' | cut -d'/' -f1 | sed 's/$$/:8000/'
	npx zenn preview

new:
	@echo "use: npx zenn new:article --slug xxx"

commit:
	claude -p "日本語1行メッセージでコミットしてください。AI署名は付けないでください。"

push: commit
	git log -n 1
	@echo "Press [Enter] to continue or [Ctrl+C] to cancel..."
	@read dummy
	git push
