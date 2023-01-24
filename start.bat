@echo off
chcp 65001
echo "Загрузка дистрибутива PostgreSQL"
curl -OL https://get.enterprisedb.com/postgresql/postgresql-15.1-1-windows-x64-binaries.zip
echo "Распаковка дистрибутива PostgreSQL"
powershell "Expand-Archive -Force -Path postgresql-15.1-1-windows-x64-binaries.zip -DestinationPath C:\ "
powershell "Copy-Item c:\scripts\*.sql C:\pgsql"
powershell "Copy-Item c:\scripts\*.sh C:\pgsql"
cd C:\pgsql
wsl chmod u+x *.sh
echo Запрос в Jira (Это надолго ~ 10-15 мин, файл большого объема)

wsl ./dow_raw_data.sh
::wsl curl -H "Authorization: Basic ZS5wbG90bmlrb3Y6dWNDMjdZQVRBQjNSTWlmRg" --request POST -H "Content-Type: application/json" https://helpdesk.dom.gosuslugi.ru/rest/api/2/search --data '{"jql": "project = SUPP AND issuetype != Sub-task AND status changed during (\"2022-12-01 00:00\", \"2023-01-01 00:00\") to Закрыто  AND filter = без_метки_тест ORDER BY created ASC", "maxResults":"2", "fields":["id","key", "created"], "expand":["changelog"]}' | jq . >> jira_raw.json
echo Парсим файлик
wsl ./parse_raw_data.sh

::wsl jq -r '.issues[] | [.key,.fields.created] | @csv' jira_raw.json >> created.csv
::wsl jq -r '.issues[] | {key, changelog: .changelog.histories[]} | select(.changelog.items[].field=="status") | [.key,.changelog.created,.changelog.author.key,.changelog.author.displayName,(.changelog.items[]| select(.field=="status")|.fromString,.toString)] | @csv' jira_raw.json >> status.csv
echo Понеслось
.\bin\initdb.exe -D  c:\pgsql\data -U postgres -E UTF8 -A trust --locale=en_US.UTF-8
.\bin\pg_ctl -D C:\pgsql\data\ -l log_file.log start
.\bin\psql -U postgres -p 5432 < create_tbl.sql
.\bin\psql -U postgres -p 5432 < script.sql
.\bin\pg_ctl -D C:\pgsql\data\ -l log_file.log stop
echo Готово