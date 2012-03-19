-- =============================================
-- Author:		Ken Taylor
-- Create date: November 19, 2009
-- Description:	This procedure gets the 205 Expenses for the Federal
-- Fiscal year and attempts to associate them with their
-- accession numbers using the award number or
-- the 4-digit numeric component of the project number
-- if the association cannot be made using the full 
-- project/award number.
-- =============================================
CREATE PROCEDURE [dbo].[sp_GET_FFY_205_EXPENSES] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009, -- Note: Federal Fiscal Year
	@IsDebug bit = 0 -- Set to 1 to print SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	declare @TSQL varchar(MAX) = '';

	IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FFY_' + Convert(char(4), @FiscalYear) + '_SFN_ENTRIES]') AND type in (N'U'))
	BEGIN
		PRINT '[dbo].[FFY_' + Convert(char(4), @FiscalYear) + '_SFN_ENTRIES] does not exist.  Run sp_GET_FFY_201_EXPENSES first!'
		RETURN
	END
ELSE
	BEGIN	
	
    -- Insert statements for procedure here
	Select @TSQL = 'INSERT INTO AD419.dbo.FFY_' + Convert(char(4), @FiscalYear) + '_SFN_ENTRIES
	(  
		Year,
		Chart,
		Org,
		Account,
		SubAccount,
		ObjConsol, 
		AwardNum,
		ExpenseSum,
		SFN,
		OrgR, 
		Accession,
		MatchedByAwardNum,
		QuadNum,
		IsActive
	)
SELECT
	Convert(int, FiscalYear) [Year],
	Chart,
	OrgCode Org,
	AccountNum Account,
	SubAccount,
	ConsolidationCode ObjConsol,
	AccountAwardNumber AwardNum,
	Convert(Money, Sum(Amount)) ExpenseSum,
	''205''  as SFN,
	(case DepartmentLevelOrg when ''none'' then OrgCode
	else DepartmentLevelOrg END) OrgR,
	Convert(varchar(50), Accession) Accession,
	Convert(bit,(CASE 
		WHEN Accession is null then 0
		ELSE 1
	END)) AS MatchedByAwardNum,
	Convert(varchar(4), null)as QuadNum,
	Convert(bit, null) as IsActive
FROM 
	FISDataMart.dbo.BalanceSummaryView 
	LEFT OUTER JOIN [AD419].[dbo].[Project] Project
		ON AccountAwardNumber = Project.[Project]
WHERE 
	(
		Chart = ''3''
		AND (
				(FiscalYear  =  ' + Convert(char(4), @FiscalYear) + '  AND FiscalPeriod in (''04'', ''05'', ''06'',''07'', ''08'', ''09'',''10'', ''11'', ''12'', ''13'' ))
			OR
				(FiscalYear =  ' + Convert(char(4), @FiscalYear + 1) + ' AND FiscalPeriod in (''01'',''02'',''03''))
			)
	)
	
	AND (TransBalanceType = ''AC'' )
	AND ConsolidationCode  Not In (''INC0'', ''BLSH'', ''SB74'')
	AND AccountNum  like ''A%''
	AND CollegeLevelOrg  IN (''AAES'', ''BIOS'')
	AND OPFund in (''21003'', ''21004'')
GROUP BY 
	Chart  ,
	FiscalYear ,
	OrgCode  ,
	AccountNum ,
	SubAccount  ,
	ConsolidationCode ,
	AccountAwardNumber,
	DepartmentLevelOrg ,
	Accession
ORDER BY 
	AccountAwardNumber,
	AccountNum,
	SubAccount ,
	ConsolidationCode,
	OrgCode ,
	FiscalYear ,
	Chart,
	DepartmentLevelOrg ,
	Accession
'
	IF @IsDebug = 1 
		BEGIN
			PRINT @TSQL;
		END
	ELSE
		BEGIN
			EXEC(@TSQL);
		END
	
	END
END

GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'This procedure gets the 205 Expenses for the Federal Fiscal year and attempts to associate them with their  accession numbers using the award number or  the 4-digit numeric component of the project number if the association cannot be made using the full project/award number.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'sp_GET_FFY_205_EXPENSES';


GO
EXECUTE sp_addextendedproperty @name = N'Parameter 1', @value = N'@FiscalYear: The Federal fiscal year for the current reporting period.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'sp_GET_FFY_205_EXPENSES';


GO
EXECUTE sp_addextendedproperty @name = N'Parameter 2', @value = N'@IsDebug: Set this bit to 1 to not execute, but only print the SQL instead.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'PROCEDURE', @level1name = N'sp_GET_FFY_205_EXPENSES';

