CREATE TABLE full_result AS 
WITH raws AS (
SELECT id, issue_key, stop_time::timestamp(0), jira_login,person_name,"1st_status", "2nd_status" FROM raw_report
), 
reports_check AS (
SELECT 
	p.id
	,p.issue_key
	,p.jira_login
	,p.person_name
	,CASE 
		WHEN p."1st_status" = 'Новая' AND p."2nd_status" = 'Новая' THEN p.stop_time
		WHEN p."1st_status" = 'Новая' AND p."2nd_status" != 'Новая' THEN c.create_date
		ELSE z.stop_time 
		END AS "start_time"
	,p.stop_time
	,p."1st_status"
	,p."2nd_status" 
FROM raws p
LEFT JOIN raws z ON p.id-1=z.id
LEFT JOIN creates c ON c.issue_key=p.issue_key
),
periods AS (
SELECT 
	id
	,issue_key
	,jira_login
	,person_name
	,start_time::timestamp(0)
	,"1st_status"
	,stop_time::timestamp(0)
	,"2nd_status"  
FROM reports_check), 
holy(dd,iswrk) AS (
  VALUES('2021-01-01'::date,false), ('2021-01-02'::date,false), ('2021-01-03'::date,false), ('2021-01-04'::date,false),
		('2021-01-05'::date,false),	('2021-01-06'::date,false), ('2021-01-08'::date,false),	('2021-01-07'::date,false),
		('2021-02-23'::date,false),	('2021-03-08'::date,false), ('2021-05-01'::date,false),	('2021-05-07'::date,false),
		('2021-06-12'::date,false),	('2021-11-04'::date,false), ('2020-01-01'::date,false),	('2020-01-02'::date,false),
		('2020-01-03'::date,false),	('2020-01-04'::date,false), ('2020-01-05'::date,false),	('2020-01-06'::date,false),
		('2020-01-07'::date,false),	('2020-01-08'::date,false), ('2020-02-24'::date,false),	('2020-03-09'::date,false),
		('2020-05-01'::date,false),	('2020-05-04'::date,false), ('2020-05-05'::date,false),	('2020-05-08'::date,false),
		('2020-05-11'::date,false),	('2020-06-12'::date,false), ('2020-10-04'::date,false)
		),
status_tbl AS (
SELECT  
	id
	,issue_key
	,jira_login
	,person_name
	,start_time
	,"1st_status"
	,stop_time
	,"2nd_status" 
	,(count(gs.d))*interval '9 hour'
	  -CASE
	       WHEN count(d)=0 OR start_time::date<min(d) THEN interval '0 hour'
	       when start_time - min(d)>=interval '18 hour' THEN interval '9 hour'
	       when start_time - min(d)<=interval '09 hour' THEN interval '0 hour'
	       ELSE start_time-min(d)-interval '09 hour'
	  END
	  -CASE WHEN count(d)=0 OR stop_time::date>max(d) THEN interval '0 hour'
	       WHEN stop_time-max(d)>=interval '18 hour' THEN interval '0 hour'
	       WHEN stop_time-max(d)<=interval '09 hour' THEN interval '9 hour'
	       ELSE interval '18 hour'- (stop_time-max(d))
	  END AS work_time
FROM periods 
LEFT JOIN LATERAL  (SELECT * FROM generate_series(start_time::date,stop_time::date,'1 day') gs(d) left join holy ON gs.d=holy.dd )gs(d,dd,iswrk) ON 
CASE WHEN extract(isodow from gs.d) IN (6,7) THEN coalesce(iswrk,false) ELSE coalesce(iswrk,true) END 
GROUP BY id,start_time,stop_time, issue_key, jira_login , person_name, "1st_status", "2nd_status"  
ORDER BY id
),
full_close AS (
SELECT id, issue_key, start_time,
"1st_status" ||' - '|| "2nd_status" AS status
,stop_time,work_time 
, CASE WHEN "1st_status" = 'Выполнено' AND "2nd_status" = 'Возвращено' THEN TRUE ELSE FALSE END AS return_check 
, CASE WHEN "2nd_status" = 'Закрыто' THEN date(stop_time) END AS close_date
FROM status_tbl
)
SELECT id, issue_key, to_char(start_time,'YYYY-MM-DD HH24:mi:ss') AS start_time, status, to_char(stop_time,'YYYY-MM-DD HH24:mi:ss') AS stop_time, work_time, return_check, CLOSE_date  FROM full_close;
COPY public.full_result TO 'c:\pgsql\result_time_report.csv' (FORMAT CSV, HEADER TRUE, DELIMITER ';', ENCODING 'UTF8');
