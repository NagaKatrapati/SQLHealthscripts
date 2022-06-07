USE [master]
GO

CREATE OR ALTER   PROC [dbo].[GetDeadlockinfo]
(@Hours int = 1)
AS
SET NOCOUNT ON;
IF EXISTS (
SELECT A.name FROM sys.dm_xe_sessions A
RIGHT JOIN sys.server_event_sessions B ON A.name = B.name
WHERE B.name = 'system_health' and A.name is NULL)
Begin
Raiserror ('The Extended Event - System_Health is in Stopped State, Please enable the Extended Event',16,1)
End

DROP TABLE IF EXISTS #errorlog
CREATE TABLE #errorlog (
            LogDate DATETIME 
            , ProcessInfo VARCHAR(100)
            , [Text] VARCHAR(MAX)
            );
DECLARE @tag VARCHAR (MAX) , @path VARCHAR(MAX);
INSERT INTO #errorlog EXEC sp_readerrorlog;
SELECT @tag = text
FROM #errorlog 
WHERE [Text] LIKE 'Logging%MSSQL\Log%';
DROP TABLE #errorlog;
SET @path = SUBSTRING(@tag, 38, CHARINDEX('MSSQL\Log', @tag) - 29);

SELECT 
  CONVERT(xml, event_data).query('/event/data/value/child::*') AS DeadlockReport,
  DATEADD(hh, DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP), CONVERT(xml, event_data).value('(event[@name="xml_deadlock_report"]/@timestamp)[1]', 'datetime') )
  AS Execution_Time
FROM sys.fn_xe_file_target_read_file(@path + '\system_health*.xel', NULL, NULL, NULL)
WHERE OBJECT_NAME like 'xml_deadlock_report'
AND DATEADD(hh, DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP), CONVERT(xml, event_data).value('(event[@name="xml_deadlock_report"]/@timestamp)[1]', 'datetime') )
  > dateadd(hh,-@Hours,getdate())
ORDER BY [Execution_Time] desc
GO


