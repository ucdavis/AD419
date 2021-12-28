

-- =============================================
-- Author:		Ken Taylor
-- Create date: May 17, 2016
-- Description:	This is the report for FTE > 1 across the included ARCs, but it also shows the FTE for the excluded ARCs in order to give the complete picture.
-- Prerequsites: 
--	 The LaborTrasactions must have been loaded.
--	 The following tables must have been updated to specify the values used for calculating the FTE totals for the current reporting period:
--		* ConsolidationCodes,
--		* DOS_Codes, and
--		* TransDocTypes.
-- Usage:
/*
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[usp_GetEmployeesWithFTEAmountsGreaterThanOne] @FiscalYear = 2021, @isDebug = 1

	SELECT	'Return Value' = @return_value

	GO
*/
-- Modifications:
--	20160816 by kjt: Revised to use [dbo].[AnotherLaborTransactions] 
--	20201020 by kjt: Revised to handle NULL PayPeriodEndDates present in
--		Fringe transactions of UC Path data, plus added ReportingYear to 
--		WHERE clause as multiple reporting years may be present.
--	20211103 by kjt: Revised to handle use with UCP version of AnotherLaborTransactions
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetEmployeesWithFTEAmountsGreaterThanOne] 
(	
	@FiscalYear int = 2021,
	@IsDebug bit = 0
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	--DECLARE @FiscalYear int = 2021
	
	SELECT
		[EmployeeID] ,
		[EmployeeName] ,
		CASE WHEN [PayPeriodEndDate] IS NULL 
			THEN [PayPeriodEndDate]
			ELSE Convert(Date,[PayPeriodEndDate]) 
		END AS  [PayPeriodEndDate],
		[Chart] ,
		[Account] ,
		[Org] ,
		[ObjConsol] ,
		[FinanceDocTypeCd] ,
		[DosCd] ,
		[TitleCd] ,
		[AnnualReportCode] ,
		[RateTypeCd] ,
		[PayRate] ,
		Convert(Money, SUM(Amount)) [Amount],
		[ExcludedByOrg] ,
		[ExcludedByARC] ,
		[ExcludedByAccount],
		CASE WHEN  SUM([PayRate]) <> 0
			THEN 
				SUM(ERN_DERIVED_PERCENT)/12
			ELSE 0 
		END AS FTE
	FROM
		[dbo].[AnotherLaborTransactions] t3
	WHERE
		ReportingYear = @FiscalYear AND DosCd <> 'XXX' AND
		EXISTS (
			SELECT t1.EMPLOYEEID 
			FROM (
				SELECT DISTINCT [EmployeeID]
				FROM
					[dbo].[AnotherLaborTransactions] 
				WHERE
					ReportingYear = @FiscalYear
				GROUP BY
					[EmployeeID] 
						--,Payrate
						,FinanceDocTypeCd, ObjConsol,DosCd
				HAVING CONVERT(DECIMAL(18, 4),
					CASE 
						WHEN  [FinanceDocTypeCd] IN (SELECT DocumentType FROM dbo.[FinanceDocTypesForFTECalc]) AND
												ObjConsol IN (SELECT Obj_Consolidatn_Num FROM dbo.[ConsolCodesForFTECalc]) AND
												DosCd IN (SELECT DOS_Code FROM dbo.DOSCodes) AND
							SUM([PayRate]) <> 0 
						THEN 
							SUM(ERN_DERIVED_PERCENT)/12
						ELSE 0 
					END) > 1.001 
				)t1
				inner join 
				(
					SELECT DISTINCT EmployeeID FROM [dbo].[AnotherLaborTransactions] 
					WHERE ExcludedByOrg = 0 AND ReportingYear = @FiscalYear AND [FringeBenefitSalaryCd] = 'S'
				
				
				) t2 ON t1.Employeeid = t2.EmployeeID
				WHERE t3.EmployeeID = t2.EmployeeID
	) 
	GROUP BY 
		[EmployeeID] ,
		[EmployeeName] ,
		[PayPeriodEndDate],
		[Chart] ,
		[Account] ,
		[Org] ,
		[ObjConsol] ,
		[FinanceDocTypeCd] ,
		[DosCd] ,
		[TitleCd] ,
		[AnnualReportCode] ,
		[RateTypeCd] ,
		[PayRate] ,
		[Amount],
		[ExcludedByOrg] ,
		[ExcludedByARC] ,
		[ExcludedByAccount]
	ORDER BY 
		[EmployeeID] ,
		[EmployeeName] ,
		[PayPeriodEndDate],
		[Chart] ,
		[Account] ,
		[Org] ,
		[ObjConsol] ,
		[FinanceDocTypeCd] ,
		[DosCd] ,
		[TitleCd] ,
		[AnnualReportCode] ,
		[RateTypeCd] ,
		[PayRate] ,
		[Amount],
		[ExcludedByOrg] ,
		[ExcludedByARC] ,
		[ExcludedByAccount]
END