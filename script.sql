CREATE TABLE (SELECT 'full_result_'||regexp_replace(to_char(date(now())-'1 month'::INTERVAL,'month_YYYY'), '\s+', '', 'g')) 
	WITH raws AS 
	(
		SELECT 
			row_number() OVER(ORDER BY issue_key,stop_time) AS id
			, issue_key
			, stop_time::timestamp(0)
			, jira_login
			, person_name
			, "1st_status"
			, "2nd_status" 
		FROM raw_report_apr
	), 
	reports_check AS 
	(
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
		LEFT JOIN creates_apr c ON c.issue_key=p.issue_key
	),
	periods AS 
	(
		SELECT 
			id
			,issue_key
			,jira_login
			,person_name
			,start_time::timestamp(0)
			,"1st_status"
			,stop_time::timestamp(0)
			,"2nd_status"  
		FROM reports_check
	), 
	holy(dd,iswrk) AS 
	(
		VALUES('2021-01-01'::date,false), ('2021-01-02'::date,false), ('2021-01-03'::date,false), ('2021-01-04'::date,false),
				('2021-01-05'::date,false),	('2021-01-06'::date,false), ('2021-01-08'::date,false),	('2021-01-07'::date,false),
				('2021-02-23'::date,false),	('2021-03-08'::date,false), ('2021-05-01'::date,false),	('2021-05-07'::date,false),
				('2021-06-12'::date,false),	('2021-11-04'::date,false), ('2020-01-01'::date,false),	('2020-01-02'::date,false),
				('2020-01-03'::date,false),	('2020-01-04'::date,false), ('2020-01-05'::date,false),	('2020-01-06'::date,false),
				('2020-01-07'::date,false),	('2020-01-08'::date,false), ('2020-02-24'::date,false),	('2020-03-09'::date,false),
				('2020-05-01'::date,false),	('2020-05-04'::date,false), ('2020-05-05'::date,false),	('2020-05-08'::date,false),
				('2020-05-11'::date,false),	('2020-06-12'::date,false), ('2020-10-04'::date,false), ('2022-11-04'::date,false),
				('2022-06-13'::date,false), ('2022-05-10'::date,false), ('2022-05-09'::date,false), ('2022-05-03'::date,false),
				('2022-05-02'::date,false), ('2022-05-01'::date,false), ('2022-03-08'::date,false), ('2022-03-07'::date,false),
				('2022-03-05'::date,true), 	('2022-02-23'::date,false), ('2022-01-09'::date,false), ('2022-01-08'::date,false),
				('2022-01-07'::date,false), ('2022-01-06'::date,false), ('2022-01-05'::date,false), ('2022-01-04'::date,false),
				('2022-01-03'::date,false), ('2022-01-02'::date,false), ('2022-01-01'::date,false), ('2023-11-06'::date,false),
				('2023-06-12'::date,false), ('2023-05-09'::date,false), ('2023-05-08'::date,false),	('2023-05-01'::date,false),
				('2023-03-08'::date,false),	('2023-02-24'::date,false), ('2023-02-23'::date,false),	('2023-01-08'::date,false),
				('2023-01-07'::date,false),	('2023-01-06'::date,false), ('2023-01-05'::date,false),	('2023-01-04'::date,false),
				('2023-01-03'::date,false),	('2023-01-02'::date,false), ('2023-01-01'::date,false)
	),
	status_tbl AS 
	(
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
	full_close AS 
	(
		SELECT 
			id
			, issue_key
			, person_name
			, start_time,
			"1st_status" ||' - '|| "2nd_status" AS status
			,stop_time,work_time 
			, CASE 
				WHEN "1st_status" = 'Выполнено' AND "2nd_status" = 'Возвращено' THEN '1' 
				ELSE '0' END AS return_check 
			, CASE 
				WHEN "2nd_status" = 'Закрыто' THEN date(stop_time) 
				END AS close_date
		FROM status_tbl
	)
	SELECT 
		fc.id
		, fc.issue_key 
		, fc.person_name
		, to_char(fc.start_time,'YYYY-MM-DD HH24:mi:ss') AS start_time
		, fc.status
		, to_char(fc.stop_time,'YYYY-MM-DD HH24:mi:ss') AS stop_time
		, fc.return_check
		, fc.CLOSE_date
		, fc.work_time AS wrk_t_minstr
		, s.minstr_stat
		, datediff AS wrk_t_all
		, s.work_stat  
	FROM full_close fc
	LEFT JOIN (
				(SELECT 
					id
					, issue_key
					, "1st_status" ||' - '|| "2nd_status" AS status
					, concat(EXTRACT(DAY FROM (stop_time-start_time))*24+EXTRACT(hour FROM (stop_time-start_time)),':',EXTRACT(minute FROM (stop_time-start_time)),':',EXTRACT(second FROM (stop_time-start_time)))::INTERVAL AS datediff 
				FROM reports_check
				)
			) cte0 ON fc.id=cte0.id
	JOIN statistic.statuses s ON fc.status=s.status
	ORDER BY id
COPY public.full_result TO 'c:\tmp\result_time_report.csv' (FORMAT CSV, HEADER TRUE, DELIMITER ';', ENCODING 'WIN1251');
