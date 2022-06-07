USE [master]
GO


CREATE OR ALTER  PROC [dbo].[GetDbPerformance]  
(@Setting nvarchar(50)='Waits')  
as
IF (@Setting = 'Help')  
Begin  
PRINT 'For System Configuration settings execute - GetDbPerformance ''Settings''' 
PRINT 'For Memory Used by Each Database execute - GetDbPerformance ''Memory'''  
PRINT 'For CPU Used by Each Database execute - GetDbPerformance ''CPU'''  
PRINT 'For IO Usage by Each Database execute - GetDbPerformance ''Disk'''  
PRINT 'For Top performing SPs execute - GetDbPerformance ''SP'''  
PRINT 'For Top performing Queries execute - GetDbPerformance ''Query'''
PRINT 'For Top Memory using Queries execute - GetDbPerformance ''MemoryQueries''' 
PRINT 'For Top TempDB using Queries execute - GetDbPerformance ''TempdbQueries'''   
PRINT 'For Top Waits in the SQL instance execute - GetDbPerformance ''Waits''' 
PRINT 'To Get all the above results execute - GetDbPerformance ''All'''  
END

IF (@Setting = 'Settings' OR @Setting ='All')  
BEGIN  
	DECLARE @CurrentValue int  
	DECLARE @SQLConfiguration table  
	( Setting nvarchar(1000),  
	  CurrentValue nvarchar(100)
	  )  
	INSERT INTO @SQLConfiguration (setting,CurrentValue)
	SELECT 'Total Physical Memory', physical_memory_kb/(1024*1024)   
	FROM sys.dm_os_sys_info;

	INSERT INTO @SQLConfiguration (setting,CurrentValue)
	SELECT  'Total Number of Cores',cpu_count  FROM sys.dm_os_sys_info;  
	
	INSERT INTO @SQLConfiguration (setting,CurrentValue) 
	SELECT  'Physical CPUs',cpu_count/hyperthread_ratio  FROM sys.dm_os_sys_info;  

	INSERT INTO @SQLConfiguration (setting,CurrentValue) 
	SELECT NAME,CAST (value_in_use as nvarchar(100)) FROM sys.configurations WHERE NAME ='Max server memory (MB)'  
  
	INSERT INTO @SQLConfiguration (setting,CurrentValue)  
	SELECT NAME,CAST (value_in_use as nvarchar(100)) FROM sys.configurations WHERE  NAME in('Max Degree of Parallelism','Cost Threshold for Parallelism')
  
	UPDATE @SQLConfiguration  
	SET Setting = 'Maximum Memory Allocated to SQLServer (GB)'  
	WHERE Setting = 'Max server memory (MB)'  
  
	SELECT @CurrentValue = Currentvalue from   
	@SQLConfiguration WHERE Setting = 'Maximum Memory Allocated to SQLServer (GB)'  
  
	UPDATE @SQLConfiguration  
	SET CurrentValue = CAST (@CurrentValue/1024 as nvarchar(200))  
	WHERE Setting = 'Maximum Memory Allocated to SQLServer (GB)'  
  
	INSERT INTO @SQLConfiguration (setting,CurrentValue)  
	SELECT 'Number of TEMPDB Files',count(*) from sys.master_files  
	WHERE db_name(database_id) = 'tempdb'  
	and NAME != 'templog'  
  
	SELECT *,GETDATE() as CheckDate FROM @SQLConfiguration  
END  
IF (@Setting = 'Memory' OR @Setting ='All')  
Begin  
	SELECT DB_NAME(database_id) as DBName,  
	COUNT (1) / (128*1024) AS CacheSizeinGB  
	FROM sys.dm_os_buffer_descriptors  
	WHERE database_id >4 AND  
	DB_NAME(database_id) IS NOT NULL  
	GROUP BY database_id  
	ORDER BY [CacheSizeinGB] DESC  
  
	SELECT [counter_name] as CounterName,  
	[cntr_value] as CurrentValue FROM sys.dm_os_performance_counters  
	WHERE [object_name] LIKE '%Manager%'  
	AND ([counter_name] = 'Page life expectancy' or   
		 [counter_name] = 'Memory Grants Pending')  
END  
IF (@Setting = 'CPU' OR @Setting ='All')  
Begin  
	WITH DB_CPU_Stats  
	AS  
	(SELECT DatabaseID, DB_Name(DatabaseID) AS [Database Name], SUM(total_worker_time) AS [CPU_Time_Ms]  
	  FROM sys.dm_exec_query_stats AS qs  
	  CROSS APPLY (SELECT CONVERT(int, value) AS [DatabaseID]   
				   FROM sys.dm_exec_plan_attributes(qs.plan_handle)  
				   WHERE attribute = N'dbid') AS F_DB  
	  GROUP BY DatabaseID)  
	SELECT ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [CPU Rank],  
			[Database Name], [CPU_Time_Ms] AS [CPU Time (ms)],   
			CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPU Percent]  
	FROM DB_CPU_Stats  
	WHERE DatabaseID <> 32767   
	ORDER BY [CPU Rank] OPTION (RECOMPILE);  
END
IF (@Setting = 'Disk' OR @Setting ='All')  
BEGIN  
 SELECT  
   DB_NAME ([vfs].[database_id]) AS [DBName],  
    [mf].[physical_name],LEFT ([mf].[physical_name], 2) AS [Drive],  
    [ReadLatency] =  
        CASE WHEN [num_of_reads] = 0  
            THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,  
    [WriteLatency] =  
        CASE WHEN [num_of_writes] = 0  
            THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,  
    [Latency] =  
        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)  
            THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,  
    [AvgBPerRead] =  
        CASE WHEN [num_of_reads] = 0  
            THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,  
    [AvgBPerWrite] =  
        CASE WHEN [num_of_writes] = 0  
            THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,  
    [AvgBPerTransfer] =  
        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)  
            THEN 0 ELSE  
                (([num_of_bytes_read] + [num_of_bytes_written]) /  
                ([num_of_reads] + [num_of_writes])) END  
    FROM  
    sys.dm_io_virtual_file_stats (NULL,NULL) AS [vfs]  
	JOIN sys.master_files AS [mf]  
    ON [vfs].[database_id] = [mf].[database_id]  
    AND [vfs].[file_id] = [mf].[file_id]  
	 WHERE DB_NAME ([vfs].[database_id])   
	 not in ('master','msdb','model')  
	ORDER BY DB_NAME ([vfs].[database_id]);  

END  
IF @Setting = 'SP' OR @Setting ='All'
BEGIN  
	SELECT top 100 DB_name(d.database_id) as DBName, OBJECT_NAME(object_id, database_id) 'SP Name',
	   d.execution_count,d.total_elapsed_time/(d.execution_count*1000000) AS [AvgElapsedTimeSec],
	   d.last_elapsed_time/1000000 AS [LastElapsedTimeSec],d.max_elapsed_time/1000000 AS [MaxElapsedTimeSec],   
	   d.total_logical_reads/d.execution_count as [Avg_logical_reads],  
	  d.total_physical_reads/d.execution_count as [Avg_physical_reads]
	FROM sys.dm_exec_procedure_stats AS d    
	WHERE d.database_id>4 and DB_NAME(d.database_id) IS NOT NULL 
	ORDER BY d.total_logical_reads desc;   
END  
  
IF (@Setting = 'Query' OR @Setting ='All')  
BEGIN  
SELECT TOP 100 SUBSTRING(qt.TEXT, (qs.statement_start_offset/2)+1,  
((CASE qs.statement_end_offset  
WHEN -1 THEN DATALENGTH(qt.TEXT)  
ELSE qs.statement_end_offset  
END - qs.statement_start_offset)/2)+1) as Querytxt,
db_name(qp.dbid) as DBName,  
qs.execution_count,  
qs.last_elapsed_time/1000000 last_elapsed_time_in_S,  
qs.total_elapsed_time/(1000000* qs.execution_count) avg_elapsed_time_in_S,  
qs.total_logical_reads/(qs.execution_count) avg_logical_reads,  
qp.query_plan  
FROM sys.dm_exec_query_stats qs  
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt  
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp  
ORDER BY qs.total_logical_reads DESC
END  

IF (@Setting = 'MemoryQueries' OR @Setting ='All')  
BEGIN
SELECT t1.session_id,
  ((t1.requested_memory_kb)/1024.00) MemoryRequestedMB
  , CASE WHEN t1.grant_time IS NULL THEN 'Waiting' ELSE 'Granted' END AS RequestStatus
  , t1.timeout_sec SecondsToTerminate
  , t2.[text] QueryText,t1.query_cost,t1.dop,db_name(t2.dbid) as DBName
FROM sys.dm_exec_query_memory_grants t1
  CROSS APPLY sys.dm_exec_sql_text(t1.sql_handle) t2
  WHERE t2.[text] not like '%MemoryRequestedMB%'
  ORDER BY t1.requested_memory_kb desc
END

IF (@Setting = 'TempdbQueries' OR @Setting ='All')  
BEGIN

SELECT
   DB_NAME(st.dbid) AS DatabaseName,
   dmv_tsu.session_id,
   SUBSTRING(st.TEXT, dmv_er.statement_start_offset / 2 + 1, 
   (
      CASE
         WHEN
            dmv_er.statement_end_offset = - 1 
         THEN
            LEN(CONVERT(NVARCHAR(MAX), st.TEXT)) * 2 
         ELSE
            dmv_er.statement_end_offset 
      END
      - dmv_er.statement_start_offset
   )
    / 2) AS QueryText, dmv_er.start_time, dmv_er.command, dmv_er.total_elapsed_time / 1000 as total_elapsed_time_Sec,
	 dmv_er.cpu_time, dmv_er.writes, dmv_er.logical_reads, dmv_tsu.user_objects_alloc_page_count, 
	 dmv_es.HOST_NAME, dmv_es.login_name 
FROM
   sys.dm_db_task_space_usage dmv_tsu 
   INNER JOIN
      sys.dm_exec_requests dmv_er 
      ON (dmv_tsu.session_id = dmv_er.session_id 
      AND dmv_tsu.request_id = dmv_er.request_id) 
   INNER JOIN
      sys.dm_exec_sessions dmv_es 
      ON (dmv_tsu.session_id = dmv_es.session_id) CROSS APPLY sys.dm_exec_sql_text(dmv_er.sql_handle) st 
WHERE
   dmv_er.total_elapsed_time / 1000 > 0 
ORDER BY
(dmv_tsu.user_objects_alloc_page_count - dmv_tsu.user_objects_dealloc_page_count) + (dmv_tsu.internal_objects_alloc_page_count - dmv_tsu.internal_objects_dealloc_page_count) DESC

END

IF (@Setting = 'Waits' OR @Setting ='All')  
BEGIN  
WITH [Waits] AS  
    (SELECT  
        [wait_type],  
        [wait_time_ms] / 1000.0 AS [WaitSec],  
        ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceSec],  
        [signal_wait_time_ms] / 1000.0 AS [SignalSec],  
        [waiting_tasks_count] AS [WaitCount],  
        100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],  
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]  
    FROM sys.dm_os_wait_stats  
    WHERE [wait_type] NOT IN (  
        N'BROKER_EVENTHANDLER',   
        N'BROKER_RECEIVE_WAITFOR',   
        N'BROKER_TASK_STOP',   
        N'BROKER_TO_FLUSH',   
        N'BROKER_TRANSMITTER',   
        N'CHECKPOINT_QUEUE',   
        N'CHKPT',   
        N'CLR_AUTO_EVENT',   
        N'CLR_MANUAL_EVENT',   
        N'CLR_SEMAPHORE',   
        N'DBMIRROR_DBM_EVENT',   
        N'DBMIRROR_EVENTS_QUEUE',   
        N'DBMIRROR_WORKER_QUEUE',   
        N'DBMIRRORING_CMD',   
        N'DIRTY_PAGE_POLL',   
        N'DISPATCHER_QUEUE_SEMAPHORE',   
        N'EXECSYNC',   
        N'FSAGENT',   
        N'FT_IFTS_SCHEDULER_IDLE_WAIT',   
        N'FT_IFTSHC_MUTEX',   
        N'HADR_CLUSAPI_CALL',   
        N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',   
        N'HADR_LOGCAPTURE_WAIT',   
        N'HADR_NOTIFICATION_DEQUEUE',  
        N'HADR_TIMER_TASK',  
        N'HADR_WORK_QUEUE',  
        N'KSOURCE_WAKEUP',  
        N'LAZYWRITER_SLEEP',  
        N'LOGMGR_QUEUE',   
        N'ONDEMAND_TASK_QUEUE',  
        N'PARALLEL_REDO_DRAIN_WORKER',  
        N'PARALLEL_REDO_LOG_CACHE',  
        N'PARALLEL_REDO_TRAN_LIST',  
        N'PARALLEL_REDO_WORKER_SYNC',  
        N'PARALLEL_REDO_WORKER_WAIT_WORK',  
		N'PREEMPTIVE_OS_FLUSHFILEBUFFERS',  
        N'PREEMPTIVE_XE_GETTARGETSTATE',  
        N'PWAIT_ALL_COMPONENTS_INITIALIZED',  
        N'PWAIT_DIRECTLOGCONSUMER_GETNEXT',  
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',  
        N'QDS_ASYNC_QUEUE',  
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',  
        N'QDS_SHUTDOWN_QUEUE',  
        N'REDO_THREAD_PENDING_WORK',  
        N'REQUEST_FOR_DEADLOCK_SEARCH',  
        N'RESOURCE_QUEUE',  
        N'SERVER_IDLE_CHECK',  
        N'SLEEP_BPOOL_FLUSH',   
        N'SLEEP_DBSTARTUP',  
        N'SLEEP_DCOMSTARTUP',  
        N'SLEEP_MASTERDBREADY',  
        N'SLEEP_MASTERMDREADY',  
        N'SLEEP_MASTERUPGRADED',  
        N'SLEEP_MSDBSTARTUP',  
        N'SLEEP_SYSTEMTASK',  
        N'SLEEP_TASK',  
        N'SLEEP_TEMPDBSTARTUP',  
        N'SNI_HTTP_ACCEPT',  
        N'SOS_WORK_DISPATCHER',  
        N'SP_SERVER_DIAGNOSTICS_SLEEP',  
        N'SQLTRACE_BUFFER_FLUSH',  
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',  
        N'SQLTRACE_WAIT_ENTRIES',  
        N'VDI_CLIENT_OTHER',  
        N'WAIT_FOR_RESULTS',  
        N'WAITFOR',  
        N'WAITFOR_TASKSHUTDOWN',   
        N'WAIT_XTP_RECOVERY',   
        N'WAIT_XTP_HOST_WAIT',   
        N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',   
        N'WAIT_XTP_CKPT_CLOSE',   
        N'XE_DISPATCHER_JOIN',   
        N'XE_DISPATCHER_WAIT',   
        N'XE_TIMER_EVENT'   
        )  
    AND [waiting_tasks_count] > 0  
    )  
SELECT  
    MAX ([W1].[wait_type]) AS [WaitType],  
    CAST (MAX ([W1].[WaitSec]) AS DECIMAL (16,2)) AS [Wait_Sec],  
    MAX ([W1].[WaitCount]) AS [WaitCount],  
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],  
    CAST ((MAX ([W1].[WaitSec]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_Sec],
	Getdate() as CheckDate
 FROM [Waits] AS [W1]  
INNER JOIN [Waits] AS [W2] ON [W2].[RowNum] <= [W1].[RowNum]  
GROUP BY [W1].[RowNum]  
HAVING SUM ([W2].[Percentage]) - MAX( [W1].[Percentage] ) < 95;   
END 
GO


