USE [master]
GO


              
 CREATE or ALTER  Procedure [dbo].[StartServerSidetrace]              
as                        
Begin              
declare @duration int --=null --Duration to run the trace, in minutes              
 ,@path varchar(200) --=null --Location to store the trace result              
 ,@tracename varchar(50) --=null              
 ,@events varchar(512) --=null              
              
select @duration=16*60              
 , @path='E:\Test'              
 , @tracename=null              
 , @events='10,41,60'              
declare @cmd nvarchar(256), @columns varchar(512)              
              
select @duration=isnull(@duration, 900)              
 ,@path=isnull(@path, 'D:\Trace')              
 ,@tracename=isnull(@tracename, 'Trace'+replace(replace(replace(convert(varchar(19), getdate(), 120), '-',''),':', ''), ' ', ''))              
 ,@events=isnull(@events,'10,41,60')              
,@columns='1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44'              
              
--Seting up trace              
select @path=@path+'\'+@tracename              
select @cmd='mkdir "'+@path+'"'              
              
exec master..xp_cmdshell @cmd              
              
declare @rc int, @traceid int              
 , @options int              
 , @tracefile nvarchar (245)              
 , @maxfilesize bigint              
 , @stoptime datetime              
              
declare @on bit              
 , @event int, @column int, @estart int, @enext int              
 , @cstart int, @cnext int              
 , @le int, @lc int              
 , @filter_num int              
              
select @options='2'              
 ,@tracefile=@path+'\trace'              
 ,@maxfilesize='25480'              
 ,@stoptime=dateadd(minute, @duration, getdate())              
 ,@on=1              
              
exec @rc = sp_trace_create @traceid output, @options, @tracefile, @maxfilesize, @stoptime              
--------------------------------------------------------------------------------------------              
-- set trace events              
select @estart = 1              
select @enext = charindex(',',@events,@estart)              
select @cstart = 1              
select @cnext = charindex(',',@columns,@cstart)              
set @le = len(@events)              
set @lc = len(@columns)              
while @enext > 0              
begin              
select @event = cast(substring(@events,@estart,@enext-@estart) as int)              
while @cnext > 0              
 begin              
 select @column = cast(substring(@columns,@cstart,@cnext-@cstart) as int)              
 exec sp_trace_setevent @traceid, @event, @column, @on              
 select @cstart = @cnext + 1              
 select @cnext = charindex(',',@columns,@cstart)              
 if @cnext = 0 set @cnext = @lc + 1              
 if @cstart >@lc set @cnext = 0              
 end              
select @cstart = 1              
select @cnext = charindex(',',@columns,@cstart)              
select @estart = @enext + 1              
select @enext = charindex(',',@events,@estart)              
if @enext = 0 set @enext = @le + 1              
if @estart > @le set @enext = 0              
end              
              
--start the trace              
exec sp_trace_setstatus @traceid, 1              
              
End       
GO


