/* The query below gives you the status for any long
runnign queries you want to check on*/

SELECT 
    r.session_id,
    r.status,
    r.blocking_session_id,   -- if > 0, THIS is your problem
    r.wait_type,
    r.wait_time,
    r.last_wait_type,
    r.command,
    DB_NAME(r.database_id) AS database_name,
    r.cpu_time,
    r.total_elapsed_time,
    r.reads,
    r.writes
FROM sys.dm_exec_requests r
WHERE r.session_id <> @@SPID and session_id=1797
ORDER BY r.session_id, r.blocking_session_id DESC, r.total_elapsed_time DESC;

