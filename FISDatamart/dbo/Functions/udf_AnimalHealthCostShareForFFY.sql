


-- =============================================
-- Author:		Ken Taylor
-- Create date: August 15, 2018
-- Description:	Return a table containing the cost shared scientist years
-- for the fiscal year and college(s) provided.
-- Usage:
/*

	USE [FISDataMart]
	GO

	SELECT * FROM udf_AnimalHealthCostShareForFFY(2019, 'BIOS,AAES')

*/
-- Modifications:
--	2019-01-18 by kjt:	Removed Sub-fund group type's Federal-Funds filtering, and now filtering by a specific list of 
--	Sub-fund group types: B, C, F, H, J, L, N, P, S, V, W and X, as per Shannon.
--	2020-09-24 by kjt: Revised to do join on distinct Labor transactions' names Vs ERS names as this table is no
--		No longer being updated.
--	2021-07-16 by kjt: Revised to use AnotherLaborTransactions as this noq contains records for all employees.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_AnimalHealthCostShareForFFY] 
(
	-- Add the parameters for the function here
	@FiscalYear int, 
	@Colleges varchar(50)
)
RETURNS 
@CostSharePercent TABLE 
(
		OpLocationCode varchar(2) NOT NULL, 
		OpFundNum varchar(6) NOT NULL,
		Org4 varchar(4) NOT NULL, 
		Chart varchar(2) NOT NULL,
		Account varchar(7) NOT NULL, 
		EmployeeId varchar(10) NULL ,
        EmployeeName varchar(50) NULL,
		StartUcFyUcFp varchar(8) NULL,
		EndUcFyUcFp varchar(8) NULL,
		CostSharingPercent int NULL,
		Months int NULL,
		FundCsYearsEmplAcctPct DECIMAL(18,3) NULL,
		FundCsYearsAllEmployees DECIMAL(18,2) NULL
)
AS
BEGIN
	INSERT INTO @CostSharePercent
	SELECT OpLocationCode, OpFundNum, Org4, Chart, Account, EmployeeId, EmployeeName, StartDate StartUcFyUcFp, EndDate EndUcFyUcFp, 
			CONVERT(int, CostSharingPercent) CostSharingPercent, Months, 
			convert(decimal(18,3), fund_cs_years_empl_acct_pct) FundCsYearsEmplAcctPct,
			convert(decimal(18,2), fund_cs_years_all_employees) FundCsYearsAllEmployees    
		FROM (
			SELECT t2.OpLocationCode, t2.OpFundNum, 
				CASE 
					WHEN Org4 IN ('AAES', 'BIOS') THEN 'AAES' 
					ELSE Org4 
				END Org4,
				t2.Chart, t2.Account, t2.EmployeeId, ers.EmployeeName,  StartDate, EndDate, 
				CostSharingPercent, months, 
				ROUND(
					   SUM(CostSharingPercent * months / 1200 )
					   over (
							PARTITION BY 
								OpLocationCode, OpFundNum
					  ),2
				) fund_cs_years_all_employees,
				ROUND(	
					SUM(CostSharingPercent * months / 1200 ) 
					over (
						PARTITION BY 
							OpLocationCode, OpFundNum, t2.Chart, t2.Account, t2.EmployeeId, CostSharingPercent, months
					),3
				) fund_cs_years_empl_acct_pct 
			FROM (
				SELECT OpLocationCode, OpFundNum, Org4, Chart, Account, EmployeeId, CostSharingPercent, CONVERT(char(4), StartFiscalYear) + CONVERT(char(2), StartFiscalPeriod) AS StartDate, CONVERT(char(4), EndFiscalYear) + CONVERT(char(2), EndFiscalPeriod) AS EndDate,
					CASE WHEN SUBSTRING(greatestBeginDate,1,4) = SUBSTRING(leastEndDate,1 ,4) THEN CONVERT(int, leastEndDate) - CONVERT(int, greatestBeginDate) + 1 
					ELSE (CONVERT(int, leastEndDate) + 9) - (CONVERT(int, greatestBeginDate) + 100 - 3) +1 END AS months
				FROM (
					select DISTINCT te.OpLocationCode, te.OpFundNum, Org4, te.Chart, te.Account, te.EmployeeId, CostSharingPercent, StartFiscalYear, StartFiscalPeriod, EndFiscalYear, EndFiscalPeriod,
						dbo.greatest(CONVERT(char(4), te.StartFiscalYear) + te.StartFiscalPeriod, CONVERT(char(4), @FiscalYear) + '04') greatestBeginDate,
						dbo.least(CONVERT(char(4), te.EndFiscalYear) +  te.EndFiscalPeriod, CONVERT(char(4), @FiscalYear + 1) + '03') leastEndDate
					from CsTrackingEntryActive te

					INNER JOIN [dbo].[Accounts] oa ON 
						oa.Year = 9999 and oa.Period= '--' AND
						oa.Chart = te.Chart and oa.Account = te.Account  

					INNER JOIN [dbo].[Organizations] oh ON 
						oh.Year = 9999 AND oh.Period = '--' AND
						oh.Chart = oa.chart and oh.Org = oa.Org and
						oh.Org4 IN (SELECT * FROM [dbo].[SplitVarcharValues](@Colleges)) 

					INNER JOIN [dbo].[OPFund] f ON  
						f.Year = 9999 AND f.Period = '--' AND
						f.Chart = te.OpLocationCode AND f.FundNum = te.OpFundNum AND
						(f.AWARDBEGINDATE < CONVERT(DATE, CONVERT(char(4), @FiscalYear) + '-10-01') OR f.AWARDBEGINDATE IS NULL) AND
						(f.AWARDENDDATE >= CONVERT(DATE, CONVERT(char(4), @FiscalYear - 1) + '-10-01') OR f.AWARDENDDATE IS NULL)

					INNER JOIN SubFundGroups sfg ON 
						sfg.YEAR = 9999 and sfg.PERIOD = '--' 
						AND sfg.SubFundGroupNum = f.SubFundGroupNum 
						AND sfg.SubFundGroupActiveIndicator = 'Y'

					INNER JOIN SubFundGroupTypes sfgt ON 
						sfgt.SubFundGroupType = sfg.SubFundGroupType AND 
						--sfgt.FederalFundsFlag = 'Y'
						sfgt.SubFundGroupType IN ('B', 'C', 'F', 'H', 'J', 'L', 'N', 'P', 'S', 'V', 'W', 'X')

					INNER JOIN [dbo].[AnotherLaborTransactions] lt ON 
						ReportingYear = @FiscalYear AND
						lt.Chart = te.Chart and lt.Account = te.Account and
						lt.EmployeeID = te.EmployeeId AND
						lt.Object NOT IN ('0054', '0520', '9998', 'HIST') AND
						lt.TitleCd IN (SELECT TitleCode FROM [PPSDataMart].[dbo].[PI_TitleCodesV]) AND
						lt.ObjConsol IN (SELECT Obj_Consolidatn_Num FROM [dbo].[ConsolCodesForFTECalc]) AND
						lt.FinanceDocTypeCd IN (SELECT DocumentType FROM [dbo].[FinanceDocTypesForFTECalc]) AND 
						lt.DosCd IN (SELECT DOS_Code FROM [dbo].[DosCodes])   
					WHERE 
						CONVERT(char(4), te.StartFiscalYear) + CONVERT(char(2), te.StartFiscalPeriod) <= CONVERT(char(4), @FiscalYear + 1) + '03' AND
						CONVERT(char(4), te.EndFiscalYear)   + CONVERT(char(2), te.EndFiscalPeriod)   >= CONVERT(char(4), @FiscalYear)     + '04' AND
						te.TrackingEntryTypeCode = 'P' AND
						te.RemovedFlag IS NULL
				) t1
			) t2
			--LEFT OUTER JOIN [dbo].[ErsEmployee] ers ON ers.EmployeeId = t2.EmployeeId
			LEFT OUTER JOIN [dbo].[udf_EmployeeNames](@FiscalYear) ers ON Ers.EmployeeId = t2.EmployeeId
		) t3
		ORDER BY OpLocationCode, OpFundNum, Chart,Account, EmployeeId, EmployeeName, StartDate, EndDate, 
		CostSharingPercent, months

	RETURN 
END