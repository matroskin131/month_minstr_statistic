CREATE TABLE public.raw_report(
	issue_key varchar(255) NULL,
	stop_time timestamp NULL,
	jira_login varchar(255) NULL,
	person_name varchar(255) NULL,
	"1st_status" varchar(255) NULL,
	"2nd_status" varchar(255) NULL
);

CREATE TABLE public.creates (
	issue_key varchar(255),
	create_date timestamp(0)
);

COPY public.raw_report FROM 'c:\pgsql\status.csv' WITH (format CSV,ENCODING UTF8);
COPY public.creates FROM 'c:\pgsql\created.csv' WITH (format CSV,ENCODING UTF8);
ALTER TABLE raw_report  ADD COLUMN id BIGSERIAL PRIMARY KEY;