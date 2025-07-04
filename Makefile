all:

preview:
	@echo -n open:
	@ip address | grep "scope global eth0" | awk '{print $2}' | cut -d'/' -f1 | sed 's/$$/:8000/'
	npx zenn preview

new:
	@echo "use: npx zenn new:article --slug xxx"

commit:
	git status
	@msg=`claude -p "git diff を確認して、日本語1行コミットメッセージ(AI署名なし)だけを出力してください。"`; echo $$msg; echo "これでcommitしますか?"; read dummy; git add .; git commit -m "$$msg"

push: commit
	git log -n 1
	@echo "このままpushしますか？"; read dummy
	git push
