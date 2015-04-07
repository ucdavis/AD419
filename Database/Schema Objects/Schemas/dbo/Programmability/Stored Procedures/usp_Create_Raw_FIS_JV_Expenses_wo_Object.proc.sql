﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: 2009-10-22
-- Description:	Creates a view for the year provided with Annual Reporting Codes
-- that are fetched from the FISDataMart.ARCCodes view.
--
-- Modifications:
--	20121107 by kjt: Added logic to remap Obj Consol codes to prior year's equiv to
--		handle mid-year obj consol code re-mapping.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Create_Raw_FIS_JV_Expenses_wo_Object]
	-- Add the parameters for the stored procedure here
	@FiscalYear char(4),
	@IsDebug bit = 0
AS
BEGIN

IF EXISTS (SELECT * FROM sysobjects WHERE name = 'Raw_FIS_JV_Expenses' AND type = 'V')
	IF @IsDebug = 1
		Begin
			Print 'DROP VIEW Raw_FIS_JV_Expenses'
		End
	ELSE
		Begin
			DROP VIEW Raw_FIS_JV_Expenses
		End

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;
	
	-- Build the list of Annual Report Codes from the ARCCodes view of the 
-- ARC_Codes table
declare @TSQL varchar(MAX) = null;

declare @ARCCodes varchar(max) = '';
declare @temp varchar(20) = '';

declare MyCursor Cursor for select ARCCode from [FISDataMart].[dbo].[ARCCodes] for READ ONLY

open MyCursor

fetch next from MyCursor into @temp

while @@FETCH_STATUS = 0
begin
	select @ARCCodes +=  '''' + @temp + '''' 
	FETCH NEXT FROM MyCursor
    INTO @temp
    
    if @@FETCH_STATUS = 0
    Begin
		select @ARCCodes += ', ' 
    End
end

close MyCursor
deallocate MyCursor

 -----------------------------------------------------------------
	select @TSQL = '
	CREATE VIEW [dbo].[Raw_FIS_JV_Expenses]
AS
SELECT  
	OrgCode AS Org, 
	AccountNum Account, 
	SubAccount, 
	--CASE WHEN OCR.ObjConsol IS NULL THEN BSV.ConsolidationCode ELSE OCR.ObjConsol END AS ObjConsol, 
	BSV.ConsolidationCode AS ObjConsol, 
	BSV.ObjectCode AS Object,
	SUM(Amount) AS Expenses
FROM    
	FISDataMart.dbo.BalanceSummaryView BSV
--LEFT OUTER JOIN [AD419].[dbo].[ObjConsolRemap] OCR ON BSV.ObjectCode = OCR.Object AND BSV.ConsolidationCode = OldObjConsol
WHERE 
	Chart = ''3''
	AND FiscalYear = ' + @FiscalYear + ' 
	AND TransBalanceType = ''AC''
	AND ConsolidationCode Not In (''INC0'', ''BLSH'', ''SB74'')
	AND AnnualReportCode IN (SELECT ArcCode FROM FISDataMart.dbo.ArcCodes) 
	AND CollegeLevelOrg IN (''AAES'', ''BIOS'')
	AND TransDocType like ''JV''
GROUP BY 
	FiscalYear, 
	OrgCode, 
	AccountNum, 
	SubAccount, 
	ConsolidationCode,
	ObjectCode

'
 -----------------------------------------------------------------
	if @IsDebug = 1
	begin
		-- Don't actuall run, but print SQL instead (for debugging purposes):
		print @TSQL
	end
	else
	begin
		-- Execute SQL:
		EXEC (@TSQL)
	end
	
END