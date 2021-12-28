

-- =============================================
-- Author:		Ken Taylor
-- Create date: July 11, 2018
-- Description:	Query the Campus' FIS data warehouse to find all of 
-- the expenses associated with Federal OP funds for the FFY provided.
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int, @IsDebug bit = 1
DECLARE @Colleges varchar(50) = 'AAES,BIOS,VETM', @FiscalYear int = 2020

EXEC	@return_value = [dbo].[usp_OpFundExpensesForFederalFiscalYear]
		@FiscalYear = @FiscalYear,
		@Colleges = @Colleges,
		@IsDebug = @IsDebug

IF @IsDebug = 0
	SELECT	'Return Value' = @return_value

*/
-- Modifications:
--	20200925 by kjt: Fixed fiscal year, fiscal period filter.
--	20210614 by kjt: Fixed issue with UB_FUND_GROUP_TYPE_CODE
-- being incorrectly named as SubFundGroupType.
--	2021-06-15 by kjt: Revised "Usage" (above) to skip printing "Return Value" string,
--		plus added column name "Colleges" to Select @Colleges statement selected when
--		@IsDebug = 1.
---	2021-07-01 by kjt: Revised join on OpFundInvestigator to use chart_num instad of OpLocationCode as this was causing
--		multiples of the total expenses based on the number of charts involved; however, ended up commenting it out
--		since it appears to no longer have any contribution to the output field list.  Also removed filtering for
--		HEFC and A11AcctNum as per Shannon, plus added HEFC as output column.
--	
-- =============================================
CREATE PROCEDURE [dbo].[usp_OpFundExpensesForFederalFiscalYear] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2017,  -- Federal Fiscal Year (FFY) to get expenses for.
	@Colleges varchar(50) = 'AAES,BIOS,VETM', -- Colleges to be included, with commas and no spaces
	@IsDebug bit = 1 -- Set to 1 to print SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL nvarchar(MAX) = ''
	DECLARE @CollegeString varchar(50) = (SELECT [master].[dbo].[udf_CreateQuotedStringList](2, @Colleges, ','))
	IF @IsDEBUG = 1 SELECT @CollegeString AS 'Colleges:'

	SELECT @TSQL = '
	SELECT 
		UC_LOC_CD,
		UC_FUND_NBR,
		ORG_ID_LEVEL_4,
		Chart_Num,
		Acct_Num,
		Expenses,
		Award_AMT,
		CONVERT(DATE, Award_Begin_Date) Award_Begin_Date,
		CONVERT(DATE, Award_End_Date) Award_End_Date,
		CGAWD_PROJ_TTL,
		SPONSOR_CODE_NAME,
		PRIMARY_PI_USER_NAME,
		EMAIL_ADDR,
		HIGHER_ED_FUNC_CODE
	FROM OPENQUERY (FIS_DS, ''SELECT
		t1.UC_LOC_CD, t1.UC_FUND_NBR, t1.ORG_ID_LEVEL_4, t1.Chart_num, t1.Acct_Num, NVL(SUM( t.TRANS_LINE_AMT),0) Expenses,
		t1.Award_AMT, t1.Award_Begin_Date, t1.Award_End_Date, t1.CGAWD_PROJ_TTL, t1.SPONSOR_CODE_NAME, t1.PRIMARY_PI_USER_NAME,
		t1.EMAIL_ADDR, t1.Higher_Ed_Func_Code 
	FROM
		(	SELECT
				UC_FUND_NBR AS UC_FUND_NBR, UC_LOC_CD,
				CASE 
					WHEN oh.ORG_ID_LEVEL_4 IN (''''AAES'''', ''''BIOS'''') THEN ''''AAES'''' 
					ELSE oh.ORG_ID_LEVEL_4 
				END AS ORG_ID_LEVEL_4,
				oa.Chart_num, oa.Acct_Num, f.AWARD_AMT Award_AMT, CGAWD_BEG_DT Award_Begin_Date,
				CGAWD_END_DT Award_End_Date, CGAWD_PROJ_TTL, 
				s.SPONSOR_CODE_NAME, f.PRIMARY_PI_USER_NAME, rkp2.EMAIL_ADDR, COALESCE(oa.Higher_Ed_Func_Code, oa.A11_Acct_Num) Higher_Ed_Func_Code
			FROM
				FINANCE.OP_FUND f 
				INNER JOIN FINANCE.AWARD A ON 
					a.UC_LOC_CD = f.OP_LOCATION_CODE AND
					a.UC_FUND_NBR = f.OP_FUND_NUM AND
					a.fiscal_year = 9999 AND
					a.fiscal_period = ''''--'''' 
				INNER JOIN FINANCE.ORGANIZATION_HIERARCHY oh ON
					oh.ORG_ID_LEVEL_4 IN (' + @CollegeString +') AND 
					oh.FISCAL_YEAR = 9999 AND
					oh.FISCAL_PERIOD = ''''--'''' AND
					oh.CHART_NUM = f.OP_LOCATION_CODE
				INNER JOIN FiNANCE.ORGANIZATION_ACCOUNT OA ON 
					oa.ORG_ID = oh.ORG_ID and 
					oa.FISCAL_YEAR = 9999 AND
					oa.FISCAL_PERIOD = ''''--'''' AND
					oa.CHART_NUM = oh.CHART_NUM AND
					oa.OP_FUND_NUM = f.OP_FUND_NUM 
					--AND (oa.HIGHER_ED_FUNC_CODE IN (''''ORES'''', ''''OAES'''') OR SUBSTR(oa.A11_ACCT_NUM,1, 2) BETWEEN ''''44'''' AND ''''59'''')
				INNER JOIN FINANCE.SUB_FUND_GROUP_TYPE sfgt ON 
					sfgt.SUB_FUND_GROUP_TYPE_CODE = oa.SUB_FUND_GROUP_TYPE_CODE AND
					--(sfgt.FEDERAL_IND = ''''Y'''' OR (sfgt.FEDERAL_IND = ''''N'''' AND sfgt.SUB_FUND_GROUP_TYPE_CODE = ''''B''''))
					sfgt.SUB_FUND_GROUP_TYPE_CODE IN (''''B'''', ''''C'''', ''''F'''', ''''H'''', ''''J'''', ''''L'''', ''''N'''', ''''P'''', ''''S'''', ''''V'''', ''''W'''', ''''X'''')
				LEFT OUTER JOIN Finance.SPONSOR s ON s.SPONSOR_CODE = f.SPONSOR_CODE 
				--LEFT OUTER JOIN FINANCE.OP_FUND_INVESTIGATOR fi ON 
				--	fi.RESPONSIBLE_IND = ''''Y'''' AND
				--	fi.OP_FUND_NUM = f.OP_FUND_NUM AND
				--	fi.FISCAL_YEAR = 9999 AND
				--	fi.FISCAL_PERIOD = ''''--'''' AND
				--	fi.CHART_NUM = f.CHART_NUM 
				LEFT OUTER JOIN FINANCE.RICE_UC_KRIM_PERSON_MV rkp2 ON 
					rkp2.DAFIS_ID = f.PRIMARY_PI_DAFIS_USER_ID AND
					rkp2.ACTV_IND = ''''Y'''' 
			WHERE
				(f.award_end_date >= to_date(''''01-Oct-' + CONVERT(varchar(4), @FiscalYear - 1) + ''''', ''''DD-MON-YYYY'''' ) OR f.award_end_date IS NULL) AND
				(f.award_begin_date < to_date(''''01-Oct-' + CONVERT(char(4),@FiscalYear) + ''''', ''''DD-MON-YYYY'''' ) OR f.award_begin_date IS NULL) AND
				(f.fiscal_year = 9999 AND f.fiscal_period = ''''--'''')
			GROUP BY
				UC_FUND_NBR,
				UC_LOC_CD,
				CASE 
					WHEN oh.ORG_ID_LEVEL_4 IN (''''AAES'''', ''''BIOS'''') THEN ''''AAES'''' 
					ELSE oh.ORG_ID_LEVEL_4 
				END,
				oa.CHART_NUM,
				oa.ACCT_NUM,
				CGAWD_BEG_DT,
				CGAWD_END_DT,
				f.AWARD_AMT,
				CGAWD_PROJ_TTL,
				s.SPONSOR_CODE_NAME,
				f.PRIMARY_PI_USER_NAME,
				rkp2.EMAIL_ADDR,
				COALESCE(oa.Higher_Ed_Func_Code, oa.A11_Acct_Num)
		) t1 
			INNER JOIN FINANCE.GL_APPLIED_TRANSACTIONS t 
			ON t.CHART_NUM = t1.CHART_NUM AND
			t.ACCT_NUM = t1.ACCT_NUM AND
			t.OBJECT_NUM NOT IN (''''0054'''', ''''0520'''', ''''9998'''', ''''HIST'''') AND
			t.BALANCE_TYPE_CODE IN (''''AC'''') 
	WHERE
		( (t.FISCAL_YEAR = ' + CONVERT(varchar(4), @FiscalYear) + ' AND t.FISCAL_PERIOD BETWEEN ''''04'''' AND ''''13'''') OR
		  (t.FISCAL_YEAR = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND t.FISCAL_PERIOD BETWEEN ''''01'''' AND ''''03'''') ) 
	GROUP BY
		t1.UC_FUND_NBR ,
		t1.UC_LOC_CD,
		t1.ORG_ID_LEVEL_4,
		t1.Chart_num,
		t1.Acct_Num,
		t1.Award_AMT,
		t1.Award_Begin_Date,
		t1.Award_End_Date,
		t1.CGAWD_PROJ_TTL,
		t1.SPONSOR_CODE_NAME,
		t1.PRIMARY_PI_USER_NAME,
		t1.EMAIL_ADDR,
		t1.HIGHER_ED_FUNC_CODE
	HAVING
		NVL(SUM( t.TRANS_LINE_AMT),0) != 0 
	ORDER BY
		UC_FUND_NBR,
		UC_LOC_CD,
		ORG_ID_LEVEL_4'')'
	
	If @IsDebug = 1
	BEGIN
		SET NOCOUNT ON
		PRINT @TSQL
	END
	ELSE
		EXEC sp_executesql @statement = @TSQL
	END