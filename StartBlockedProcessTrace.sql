USE [master]
GO


            
      
CREATE OR ALTER   Procedure [dbo].[StartBlockedProcessTrace]       
as         
Begin        
Declare @path varchar(200)       
,@rc int      
,@TraceID int      
,@maxfilesize bigint      
,@DateTime datetime      
,@tracefile nvarchar (245)       
,@tracename varchar(100)= null      
Select @tracename=isnull(@tracename, 'BlockecprocessReportDemo_'+replace(replace(replace(convert(varchar(19), getdate(), 120), '-',''),':', ''), ' ', ''));      
set @path =  'D:\Trace\BlockedProcess'      
select @tracefile=@path+'\'+@tracename        
      
      
---------Added a function here:      
set @DateTime = DATEADD(mi,900,getdate()); /* Run for five minutes */      
set @maxfilesize = 20481      
      
exec @rc = sp_trace_create @TraceID output, 0, @tracefile, @maxfilesize, @Datetime      
if (@rc != 0) goto error      
       
declare @on bit      
set @on = 1      
exec sp_trace_setevent @TraceID, 137, 1, @on      
exec sp_trace_setevent @TraceID, 137, 12, @on      
      
declare @intfilter int      
declare @bigintfilter bigint      
       
      
exec sp_trace_setstatus @TraceID, 1      
       
      
select TraceID=@TraceID      
goto finish      
       
error:      
select ErrorCode=@rc      
       
finish:      
End      
    
GO


