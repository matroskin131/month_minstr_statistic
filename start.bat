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
echo Парсим файлик
wsl ./parse_raw_data.sh
echo Понеслось
.\bin\initdb.exe -D  c:\pgsql\data -U postgres -E UTF8 -A trust --locale=en_US.UTF-8
.\bin\pg_ctl -D C:\pgsql\data\ -l log_file.log start
.\bin\psql -U postgres -p 5432 < create_tbl.sql
.\bin\psql -U postgres -p 5432 < script.sql
.\bin\pg_ctl -D C:\pgsql\data\ -l log_file.log stop
echo Готово