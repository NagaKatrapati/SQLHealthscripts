USE [master]
GO



CREATE OR ALTER    Proc [dbo].[GetRootBlocker]
(@starttime datetime, @endtime datetime)
as
;WITH T_BLOCKERS AS
(
 -- Find block Leaders
 SELECT r.[dd hh:mm:ss.mss], r.[session_id], r.[sql_text],
 [batch_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_command],r.[sql_text]) AS NVARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''),
 r.[sql_command], r.[login_name], r.[wait_info], r.[tempdb_allocations], r.[tempdb_current], 
 r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[physical_reads], r.[CPU], r.[used_memory], r.[status], r.[open_tran_count], 
 r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.locks, r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
 ,[LEVEL] = CAST (REPLICATE ('0', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
 FROM Lw_monitor..Whoisactive AS r
 WHERE (ISNULL(r.blocking_session_id,0) = 0 OR ISNULL(r.blocking_session_id,0) = r.session_id)
 AND EXISTS (SELECT * FROM Lw_monitor..whoisactive AS R2 WHERE R2.collection_time = r.collection_time AND ISNULL(R2.blocking_session_id,0) = r.session_id AND ISNULL(R2.blocking_session_id,0) <> R2.session_id)
 --	
 UNION ALL
 --
 SELECT r.[dd hh:mm:ss.mss], r.[session_id], r.[sql_text],
 [batch_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_command],r.[sql_text]) AS NVARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''),
 r.[sql_command], r.[login_name], r.[wait_info], r.[tempdb_allocations], r.[tempdb_current], 
 r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[physical_reads], r.[CPU], r.[used_memory], r.[status], r.[open_tran_count], 
 r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.locks, r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
 ,CAST (B.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL
 FROM Lw_monitor..whoisactive AS r
 INNER JOIN 
 T_BLOCKERS AS B
 ON r.collection_time = B.collection_time
 AND r.blocking_session_id = B.session_id
 WHERE r.blocking_session_id <> r.session_id
)
--select * from T_BLOCKERS
SELECT [BLOCKING_TREE] = N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) 
 + CASE WHEN (LEN(LEVEL)/4 - 1) = 0
 THEN 'RootBlocker -  '
 ELSE '|------  ' 
 END
 + CAST (r.session_id AS NVARCHAR (10)) + N' ' + (CASE WHEN LEFT(r.[batch_text],1) = '(' THEN SUBSTRING(r.[batch_text],CHARINDEX('exec',r.[batch_text]),LEN(r.[batch_text]))  ELSE r.[batch_text] END),
 r.[dd hh:mm:ss.mss], r.[wait_info], r.[blocked_session_count], r.[blocking_session_id],
 r.[login_name], r.[host_name], r.[database_name], r.[program_name], r.locks, r.[tempdb_allocations], r.[tempdb_current], 
 r.[reads], r.[writes], r.[physical_reads], r.[CPU], r.[used_memory],  r.[open_tran_count], 
 r.[start_time], r.[login_time], [sql_command]
 ,r.[collection_time]
FROM T_BLOCKERS AS r
Where collection_time > @starttime
and collection_time < @endtime
and login_name = 'development'
ORDER BY collection_time, LEVEL ASC;
GO


