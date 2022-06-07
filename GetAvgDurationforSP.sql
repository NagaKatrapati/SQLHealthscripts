USE [master]
GO



CREATE OR ALTER     Proc [dbo].[GetAvgDurationforSP] 
(@Dbname sysname,@SPname sysname,@starttime datetimeoffset,@endtime datetimeoffset)
As
Set nocount on;

Drop table if exists #AvgDurationforSP

Declare @sql nvarchar(max)='Use '+@Dbname+'; '+
'SELECT cast (rs.avg_duration/1000000 as decimal (7,2)) as [avg_duration_Sec],rs.max_duration/1000000 as maxDurationSec,
count_executions as [Count],object_name(q.object_id) as [objectname] into #AvgDurationforSP
 FROM sys.query_store_query_text AS qt JOIN sys.query_store_query AS q
ON qt.query_text_id = q.query_text_id JOIN sys.query_store_plan AS p
ON q.query_id = p.query_id JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
WHERE  rs.last_execution_time > '+ ''''+cast(@starttime as nvarchar(100))+''''+
' and rs.last_execution_time < '+ ''''+cast (@endtime as nvarchar(100))+''''+
' and object_name(q.object_id) ='+''''+@SPname+''''+' ;
select @SPname as SPName, sum(count) as CountExecutions, Cast (Avg(avg_duration_sec) as Decimal (7,2)) as AvgDurationSec, 
Cast (max(maxDurationSec) as Decimal (7,2))  as MaxDurationSec  from #AvgDurationforSP'
Exec sp_executesql @sql ,N'@SPname NVARCHAR(150)', @SPname;

GO


