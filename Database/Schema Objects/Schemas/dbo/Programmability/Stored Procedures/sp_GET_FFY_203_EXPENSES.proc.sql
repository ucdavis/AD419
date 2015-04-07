-- =============================================
-- Author:		Ken Taylor
-- Create date: November 19, 2009
-- Description:	This procedure gets the 203 Expenses for the Federal
-- Fiscal year and attempts to associate them with their
-- accession numbers using the award number or
-- the 4-digit numeric component of the project number
-- if the association cannot be made using the full 
-- project/award number.
-- ran in 3:54
-- Modifications:
--	2015-03-20 by kjt:
-- Revised to use Expenses_CAES table, which now only holds FFY expense data.
--   also modified project number matching to match more projects.
-- =============================================
CREATE PROCEDURE sp_GET_FFY_203_EXPENSES 
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
Select @TSQL += 'INSERT INTO dbo.FFY_' + Convert(char(4), @FiscalYear) + '_SFN_ENTRIES
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
	Convert(int, FYr) [Year],
	t1.Chart,
	t1.Org,
	t1.Account,
	SubAccount,
	ObjConsol,
	t2.AwardNum,
	Convert(Money, Sum(ExpenseSum)) ExpenseSum,
	''203''  as SFN,
	(case Org_R when ''none'' then t1.Org
	else Org_R END) OrgR,
	Convert(varchar(50), Accession) Accession,
	Convert(bit,(CASE 
		WHEN Accession is null then 0
		ELSE 1
	END)) AS MatchedByAwardNum,
	Convert(varchar(4), null)as QuadNum,
	Convert(bit, null) as IsActive
FROM 
	[dbo].[Expenses_CAES] t1 
	left outer join FISDatamart.dbo.accounts t2 on t1.account = t2.account and t1.chart = t2.chart and year = 9999 and period = ''--''
	left outer join FISDatamart.dbo.OPFund t3 ON t2.OpFundNum = t3.FundNum AND  t2.Year = t3.Year and t2.Chart = t3.chart and t2.Period = t3.Period
	left outer join [dbo].[Project] t4 ON 
		t2.AwardNum = t4.CSREES_ContractNo OR -- First match by account award number
		t3.AwardNum = t4.CSREES_ContractNo OR -- then by OP Fund Award Number
		t4.CSREES_ContractNo LIKE ''%'' + t2.AwardNum -- lastly by a missing "20" at the beginning of the award number.
		OR t2.AwardNum = t4.Project
		OR t4.Project LIKE REPLACE(t2.AwardNum, ''*'', ''%'')
WHERE 
	t1.Account like ''A%'' AND
	left(OpFundNum,5) in (''21007'',''21008'')
GROUP BY 
	t1.Chart  ,
	FYr ,
	t1.Org  ,
	t1.Account ,
	SubAccount  ,
	ObjConsol ,
	t2.AwardNum,
	Org_R ,
	Accession
ORDER BY 
	t2.AwardNum,
	t1.Account,
	SubAccount ,
	ObjConsol,
	Org ,
	FYr ,
	t1.Chart,
	Org_R ,
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