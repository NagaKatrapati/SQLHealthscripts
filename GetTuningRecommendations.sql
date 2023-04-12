


CREATE or ALTER PROC [dbo].[GetTuningRecommendations] 
(@dbname SYSNAME)
AS
  SET NOCOUNT ON;
  DECLARE @sql NVARCHAR(max);
  if not exists(select * from sys.databases where name= @dbname)
  begin
    RAISERROR('Database does not exist!',11,1);
	return
  end
---Check if Querystore is enabled. Enable Querystore if its turned off

  SET @sql = 'IF not EXISTS(SELECT * FROM '+@dbname+'.sys.database_query_store_options where actual_state_desc = ''READ_WRITE'')
   BEGIN
		ALTER DATABASE [' + @DBname + '] SET QUERY_STORE = ON;  ALTER DATABASE [' + @DBname +
	']  SET QUERY_STORE (OPERATION_MODE = READ_WRITE, MAX_STORAGE_SIZE_MB = 4096, QUERY_CAPTURE_MODE = AUTO);
    print ''Enabled query store!''
   END'
   EXEC sp_executesql @sql

---Check if Automatic Plan forcing is enabled. Print error if its not enabled.

  SET @sql = 'IF not EXISTS(SELECT * FROM '+@dbname+
  '.sys.database_automatic_tuning_options where name = ''FORCE_LAST_GOOD_PLAN'' and actual_state_desc = ''ON'')
  BEGIN   
	 ALTER DATABASE ['+@dbname +'] SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON);
     print ''Enabled AUTOMATIC_TUNING!''
  END'
  EXEC sp_executesql @sql
---Get Tuning Recommendations from System table

  SET @sql = 'use ['+@dbname+']; WITH DbTuneRec
AS (SELECT ddtr.reason,
           ddtr.score,
           pfd.query_id,
           pfd.regressedPlanId,
           pfd.recommendedPlanId,
           JSON_VALUE(ddtr.state,
                      ''$.currentValue'') AS CurrentState,
           JSON_VALUE(ddtr.state,
                      ''$.reason'') AS CurrentStateReason,
           JSON_VALUE(ddtr.details,
                      ''$.implementationDetails.script'') AS ImplementationScript
    FROM sys.dm_db_tuning_recommendations AS ddtr
        CROSS APPLY
        OPENJSON(ddtr.details,
                 ''$.planForceDetails'')
        WITH (query_id INT ''$.queryId'',
              regressedPlanId INT ''$.regressedPlanId'',
              recommendedPlanId INT ''$.recommendedPlanId'') AS pfd)
SELECT qsq.query_id,
       dtr.reason,
       dtr.score,
       dtr.CurrentState,
       dtr.CurrentStateReason,
       qsqt.query_sql_text,
       CAST(rp.query_plan AS XML) AS RegressedPlan,
       CAST(sp.query_plan AS XML) AS SuggestedPlan,
       dtr.ImplementationScript
FROM DbTuneRec AS dtr
    JOIN sys.query_store_plan AS rp
        ON rp.query_id = dtr.query_id
           AND rp.plan_id = dtr.regressedPlanId
    JOIN sys.query_store_plan AS sp
        ON sp.query_id = dtr.query_id
           AND sp.plan_id = dtr.recommendedPlanId
    JOIN sys.query_store_query AS qsq
        ON qsq.query_id = rp.query_id
    JOIN sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id;'
 EXEC sp_executesql @sql
GO
