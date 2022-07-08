
Create Procedure GetIOErrordetailsfromSQLLog
as
Set nocount on;
Drop Table IF exists #SQLErrorLog
Drop Table IF exists #NoIOErrorsTemp
CREATE TABLE #SQLErrorLog
(
LogDate DATETIME,
ProcessInfo VARCHAR(20),
Text1 VARCHAR(max)
)
INSERT INTO #SQLErrorLog
EXEC xp_readerrorlog 0

select Logdate,text1
from #SQLErrorLog 
where TEXT1 like 'SQL Server has encountered%' 
order by logdate desc

select Logdate,TRIM ('SQL Server has encountered ' FROM SUBSTRING(Text1,0,Charindex ('occurrence',Text1))) AS NoofErrors,
CAST( Logdate AS DATE) as Date1
Into #NoIOErrorsTemp
from #SQLErrorLog 
where TEXT1 like 'SQL Server has encountered%' 


Select sum (Cast(NoofErrors as bigint)) as TotalIOErrorsPerDay,Date1 from #NoIOErrorsTemp
Group by Date1
Order by Date1 desc

GO