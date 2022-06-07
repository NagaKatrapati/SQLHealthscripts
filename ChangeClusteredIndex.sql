
  
CREATE OR ALTER PROCEDURE [dbo].[ChangeClusteredIndex] (@table_name sysname,@reqcolumn nvarchar(200))  
as  
  
Set Nocount ON;  
  
Declare @fk_name sysname  
              ,@fk_table sysname  
              ,@fk_column nvarchar(100)  
              ,@pk_name sysname  
              ,@pk_column nvarchar(100)  
              ,@clindex nvarchar(500)  
              ,@existingindex nvarchar(500) 
			  ,@deleterule nvarchar(100)
	          ,@updaterule nvarchar(100)    
              ,@sql1 nvarchar(max)  
              ,@sql2 nvarchar(max);  
  
If Exists (  
                             select A.name from sys.columns A  
                             join sys.tables B on a.object_id = B.object_id  
                             where b.type='U' and B.name = @table_name and A.name = @reqcolumn  
                             )  
Begin    
  
if not exists (  
                             select c.name  
                             from sys.indexes i  
                             inner join sys.index_columns a on i.object_id = a.object_id  
                                           and i.index_id = a.index_id  
                             inner join sys.columns b on a.object_id = b.object_id  
                                           and a.column_id = b.column_id  
                             inner join sys.tables c on i.object_id = c.object_id  
                             where i.type_desc = 'clustered'  
                                           and c.name = @table_name  
                                           and b.name = @reqcolumn  
                             )  
Begin         
  
if object_id('tempdb..#listforeignkeys') is not null  
              drop table #listforeignkeys  
  
if object_id('tempdb..#listprimarykeys') is not null  
              drop table #listprimarykeys  
  
select a.constraint_name fk_name  
              ,b.table_name fk_table  
              ,b.column_name fk_column  
              ,a.unique_constraint_name pk_name  
              ,c.table_name pk_table  
              ,c.column_name pk_column
	      ,a.DELETE_RULE
	      ,a.UPDATE_RULE   
into #listforeignkeys  
from information_schema.referential_constraints a  
join information_schema.key_column_usage b on a.constraint_name = b.constraint_name  
join information_schema.key_column_usage c on a.unique_constraint_name = c.constraint_name  
where c.table_name = @table_name  
order by fk_table;  
  
Declare Mycursor1 cursor fast_forward for  
select fk_name  
from #listforeignkeys  
  
Open mycursor1  
Fetch next from Mycursor1 into @fk_name  
  
While @@fetch_status = 0  
Begin  
              select @fk_table = fk_table  
              from #listforeignkeys  
              where fk_name = @fk_name  
  
              set @sql1 = 'Alter Table ' + @fk_table + ' Drop Constraint ' + @fk_name  
              exec sp_executesql @sql1  
              print 'Deleting ForeignKey [' + @fk_name + '] in the table ' + @fk_table  
  
              Fetch next from mycursor1 into @fk_name  
End  
  
Close Mycursor1  
Deallocate Mycursor1  
  
select column_name  
                ,constraint_name  
into #listprimarykeys  
from information_schema.key_column_usage  
where objectproperty(object_id(constraint_schema + '.' + quotename(constraint_name)), 'isprimarykey') = 1  
              and table_name = @table_name  
  
select @pk_name = constraint_name  
                ,@pk_column = column_name  
from #listprimarykeys  
  
set @sql1 = 'Alter Table ' + @table_name + ' Drop Constraint ' + @pk_name  
  
exec sp_executesql @sql1  
  
print 'Deleting PrimaryKey [' + @pk_name + '] in the table ' + @table_name  
  
If Exists (  
                             select  A.name from sys.indexes A  
                             join sys.tables B on A.object_id = b.object_id  
                             where b.Type = 'U' and A.type_desc = 'CLUSTERED'  
                             and object_name(A.object_id) = @table_name)  
Begin  
                             select @existingindex= A.name from sys.indexes A  
                             join sys.tables B on A.object_id = b.object_id  
                             where b.Type = 'U' and A.type_desc = 'CLUSTERED'  
                             and object_name(A.object_id) = @table_name  
set @sql2=  'DROP INDEX ['+@existingindex+']  ON ['+@table_name+'] WITH ( ONLINE = OFF )'  
exec sp_executesql @sql2  
End  

If (@reqcolumn !=@pk_column)
Begin
set @clindex = 'ClusteredIndex_' + @reqcolumn  
set @sql1 = 'Create Clustered Index [' + @clindex + '] on [' + @table_name + '] ( [' + @reqcolumn + '] asc)'  
  
exec sp_executesql @sql1  
End

print char(8);  
print 'Creating ClusteredIndex on the column - ' + @reqcolumn  
print char(8);  
  
set @sql1 = 'Alter Table ' + @table_name + ' Add  Primary key ('  + @pk_column + ')'  
  
exec sp_executesql @sql1  
  
print 'Recreating PrimaryKey on column [' + @pk_column + ']'  
  
Declare Mycursor1 cursor fast_forward for  
select fk_name  
from #listforeignkeys  
  
Open Mycursor1  
Fetch next from Mycursor1 into @fk_name  
  
While @@fetch_status = 0  
Begin  
              select @fk_table = fk_table    
                     ,@fk_column = fk_column
		     ,@deleterule = DELETE_RULE
		     ,@updaterule = UPDATE_RULE    
              from #listforeignkeys    
              where fk_name = @fk_name 
  
              set @sql1 = 'Alter Table ' + @fk_table + ' Add  Constraint ' + @fk_name + ' Foreign Key ('+ 
			  @fk_column + ') references ' + @table_name + '(' + @pk_column + ') ON DELETE ' 
			  +@deleterule+ ' ON UPDATE '+ @updaterule    
              exec sp_executesql @sql1    
              print 'Recreating ForeignKey [' + @fk_name + '] with Delete '+@deleterule+' and with Update '+@updaterule+' on the table '  + @fk_table       
    
              Fetch next from Mycursor1 into @fk_name   
End  
  
Close Mycursor1  
Deallocate Mycursor1  
end
else
begin
print 'Clustered Index already exists on the column, Enter a different column name. TableName : '+@table_name+', Column Name : '+@reqcolumn 
end
end
else
begin
print 'Table or Column Doesnot exist, Enter a Valid name. TableName : '+@table_name+', Column Name : '+@reqcolumn
end
GO


