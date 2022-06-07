/*The Stored procedure exports all the SSIS packages (including subfolders) to Filesystem and creates text file with dtutil commands to import the packages from filesystem to msdb*/
/*To run the sp- Exec US_Packages 'D:\Test\ */


Create or Alter Procedure [dbo].[ExportSSISpackages]
@Source Varchar(1000)
as
begin
Declare @name varchar(500)
Declare @sql varchar(2000);
Declare @instancename as sysname;
Declare @sql1 as varchar(2000);
select @instancename = @@SERVERNAME;

WITH FOLDERS AS
(
 SELECT
 cast(PF.foldername AS varchar(max)) AS FolderPath
 ,PF.folderid
 ,PF.parentfolderid
 ,PF.foldername
 FROM
 msdb.dbo.sysssispackagefolders PF
 WHERE
 PF.parentfolderid IS NULL
 UNION ALL
 SELECT
 cast(F.FolderPath + '\' + PF.foldername AS varchar(max)) AS FolderPath
 ,PF.folderid
 ,PF.parentfolderid
 ,PF.foldername
 FROM
 msdb.dbo.sysssispackagefolders PF
 INNER JOIN
 FOLDERS F
 ON F.folderid = PF.parentfolderid
)
, PACKAGES AS
(
 SELECT
 P.name AS PackageName,
 P.id AS PackageId,
 P.description as PackageDescription,
 P.folderid
 ,P.packageFormat,P.packageType,P.vermajor,P.verminor,P.verbuild,suser_sname(P.ownersid) AS ownername
 FROM
 msdb.dbo.sysssispackages P
)
 SELECT PackageName,
'dtutil /SOURCESERVER "' + @@SERVERNAME + '" /SQL "'+ F.FolderPath + '\' + P.PackageName + '" /Q /COPY FILE;"'+@Source + P.PackageName +'.dtsx"' AS cmd,
'dtutil /destserver ' + @@SERVERNAME + ' /FILE "'+@Source + P.PackageName +'.dtsx'+ '" /Q /COPY SQL;"'+ F.FolderPath + '\' + P.PackageName+'"' as output1
into Master..SSISPackages_Temp
FROM 
 FOLDERS F
 INNER JOIN
 PACKAGES P
 ON P.folderid = F.folderid
 where foldername not in ('Data Collector','Maintenance Plans')

Declare Mycursor1 Cursor Fast_Forward For
select PackageName from Master..SSISPackages_Temp
Open Mycursor1
Fetch Next from Mycursor1 into @name
while @@Fetch_status= 0
begin
select @sql = cmd from Master..SSISPackages_Temp where PackageName = @name
exec xp_cmdshell @sql
Fetch Next from Mycursor1 into @name
end
Close Mycursor1
DEALLOCATE Mycursor1
Insert into Master..SSISPackages_Temp values ('','','/*Output to be run in CommandPrompt.The script will export all the packages to msdb from filesystem. Prior to running this script
1)Change Destination server to DR server/instancename
2)Create any subfolders needed in Integration services.
*/
');
set @sql1= 'sqlcmd -S ' + @instancename + ' -E -h -1 -d master -Q "set nocount on; Select output1 from Master..SSISPackages_Temp " -o "'+@Source+'Output_ToRun_in_CMD.txt"'
exec xp_cmdshell @sql1
Drop table Master..SSISPackages_Temp
End

GO