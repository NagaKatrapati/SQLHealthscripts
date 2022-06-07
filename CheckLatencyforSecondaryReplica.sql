
USE PRODDBA
GO

DROP TABLE IF EXISTS [SecondaryReplicaLag_2]
GO
DROP TABLE IF EXISTS [SecondaryReplicaLag_3]
GO
CREATE TABLE [dbo].[SecondaryReplicaLag_2](
	[DBNAME] [nvarchar](128) NULL,
	[replica_server_name] [nvarchar](256) NULL,
	[last_redone_time] [datetime] NULL,
	[ReceiveLatencyS] [int] NULL,
	[RedoLatencyS] [int] NULL,
	[MinToRedo] [numeric](12, 3) NULL,
	[SecToLogSend] [numeric](12, 3) NULL,
	[SendQueue] [bigint] NULL
) ON [PRIMARY]
GO
CREATE TABLE [dbo].[SecondaryReplicaLag_3](
	[DBNAME] [nvarchar](128) NULL,
	[MilliSeconds behind] [int] NULL,
	[Seconds behind] [decimal](18, 2) NULL,
	[Minutes behind] [decimal](18, 2) NULL,
	[Redo Queue size in KB] [bigint] NULL,
	[Redo Rate KB/second] [bigint] NULL,
	[datetime] [datetime] NOT NULL
) ON [PRIMARY]
GO





USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'CheckLatencyforSecondaryReplica', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step1]    Script Date: 6/7/2022 8:45:35 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
Insert into ProdDBA..SecondaryReplicaLag_2
SELECT DB_NAME(database_id) as DBNAME,
       a.replica_server_name,
       last_redone_time,
       DATEDIFF(MINUTE, last_sent_time, last_received_time) AS ReceiveLatencyS,
       DATEDIFF(SECOND, last_sent_time, last_redone_time) AS RedoLatencyS,
       CASE
           WHEN redo_queue_size = 0 THEN 0
           WHEN redo_rate = 0 THEN 0
           ELSE
               CAST(redo_queue_size / (redo_rate * 1.0) AS NUMERIC(12, 3))
       END AS MinToRedo,
       CASE
           WHEN log_send_queue_size = 0 THEN 0
           WHEN log_send_rate = 0 THEN 0
           ELSE
               CAST(log_send_queue_size / (log_send_rate * 1.0) AS NUMERIC(12, 3))
       END AS SecToLogSend,
       log_send_queue_size AS SendQueue
	   
FROM sys.dm_hadr_database_replica_states d
    JOIN sys.availability_replicas a
        ON d.replica_id = a.replica_id
WHERE d.last_redone_time IS NOT NULL




insert into ProdDBA..SecondaryReplicaLag_3
Select DB_NAME(database_id) as DBNAME,
	datediff(ms,last_redone_time,last_hardened_time) as [MilliSeconds behind]
	,Cast((datediff(ss,last_redone_time,last_hardened_time)) as decimal(18,2)) as [Seconds behind]
	,Cast((datediff(mi,last_redone_time,last_hardened_time)) as decimal(18,2)) as [Minutes behind]
	,redo_queue_size as [Redo Queue size in KB]
	,redo_rate as [Redo Rate KB/second]
	, getdate() as [datetime]
	 
From sys.dm_hadr_database_replica_states
Where 1=1
	and is_primary_replica = 0

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Step1', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=30, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210120, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


