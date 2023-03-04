--CREATE PROCEDURE [dbo].[st_custom_report_direct_ship_procurement]
--@company_number CHAR(5)
--/*
--exec dataWarehouseV2.dbo.st_custom_report_direct_ship_procurement @company_number = '00750'
--*/
--AS
--BEGIN

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF OBJECT_ID ('staging..ProRewardsAnnualExport') IS NOT NULL DROP TABLE staging..ProRewardsAnnualExport;
--IF OBJECT_ID ('Staging.dbo.DirectShipProcurementReport') IS NOT NULL DROP TABLE Staging..DirectShipProcurementReport;
--CREATE TABLE staging.dbo.DirectShipProcurementReport (
--          Item_Number					VARCHAR(MAX)
--		, Item_Descripton				VARCHAR(30)
--        , MF_Code						VARCHAR(MAX)
--		, PD_Code						VARCHAR(MAX)
--		, VN_Code						VARCHAR(MAX)
--		, On_BO							INT
--		, On_PO							INT
--       );
																				
--Debugging Value
--DECLARE @company_number CHAR(5) = '00750'

DECLARE @sql NVARCHAR(MAX);


Declare @db_name varchar(500), @table_name varchar(500), @file_name varchar(500) , @PATH varchar(500), @PathAndFile varchar(500)
SET @table_name = 'ProRewardsAnnualExport'
SET @db_name = 'staging'
SET @Path = '\\volans\data\Export\ProRewards\'
SET @file_name = @Path + 'Prorewards_2012_1.csv'

declare @columns varchar(8000), @data_file varchar(200)

SELECT a.company_number
,a.customer_number
,c.mailing_address_line_1
,c.mailing_address_line_2
,c.mailing_address_line_3
,c.mailing_city
,c.mailing_state
,c.mailing_zip_code
,c.email_address
,SUM(b.line_amount) sales
,SUM(b.line_amount-b.cogs_amount) gm$
,SUM (b.line_amount-b.cogs_amount)/NULLIF(SUM(b.line_amount),0)gm_pct
into staging.dbo.ProRewardsAnnualExport
FROM dbo.invoice_header a
JOIN dbo.invoice_line b
ON b.invoice_key = a.invoice_key
LEFT JOIN dbo.customer_dim_current c
ON a.customer_durable_key=c.customer_durable_key
join (SELECT company_durable_key FROM dbo.vw_wise_nightly_companies  where company_number < '00900' and organization_type = 'LOCO')x
on x.company_durable_key = a.company_durable_key
WHERE a.yearmo_key BETWEEN 202203 AND 202302
--AND a.company_number NOT IN ('00002','00003','00102','00202','00302','00602','00942')
--AND a.company_number<'00900'
GROUP BY a.company_number
,a.customer_number
,c.mailing_address_line_1
,c.mailing_address_line_2
,c.mailing_address_line_3
,c.mailing_city
,c.mailing_state
,c.mailing_zip_code
,c.email_address
ORDER BY a.company_number,a.customer_number


--EXEC (@sql);

--Generate column names as a recordset
select  
	@columns=coalesce(@columns+',','')+column_name+' as '''''+column_name + ''''''
from 
	staging.information_schema.columns
where 
	table_name= @table_name
	print @columns
select @columns=''''''+replace(replace(@columns,' as ',''''' as '),',',',''''')

--Create a dummy file to have actual data
select @data_file=@PATH +'data_file.csv'
print @file_name

--Generate column names in the passed EXCEL file
set @sql='exec master..xp_cmdshell ''bcp " select * from (select '+@columns+') as t" queryout "'+@file_name+'" -T -c  -t"," -S volans.winwholesale.com'''
print @SQL
exec(@sql)

--Generate data in the dummy file
set @sql='exec master..xp_cmdshell ''bcp "staging.dbo.ProRewardsAnnualExport" out "'+@data_file+'" -T -t"," -c -S volans.winwholesale.com'''
print @SQL
exec(@sql)

--Copy dummy file to passed EXCEL file
set @sql= 'exec master..xp_cmdshell ''type '+@data_file+' >> "'+@file_name+'"'''
print @SQL
exec(@sql)

--Delete dummy file 
set @sql= 'exec master..xp_cmdshell ''del '+@data_file+''''
print @SQL
exec(@sql)


