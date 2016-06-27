
-- asm-space-schedule.sql
-- rather basic job setup

BEGIN
	DBMS_SCHEDULER.create_job (
		job_name        => 'ASM_Space_Metrics',
		job_type        => 'PLSQL_BLOCK',
		job_action      => 'BEGIN asm_space.run; END;',
		--start_date      => SYSTIMESTAMP,
		--repeat_interval => 'freq=minutely; interval=5; bysecond=0;',
		-- start 1 hour from now
		start_date           =>  SYSTIMESTAMP + interval '1' Hour
		repeat_interval      => 'FREQ=DAILY', 
		enabled         => TRUE
	);
END;
/




