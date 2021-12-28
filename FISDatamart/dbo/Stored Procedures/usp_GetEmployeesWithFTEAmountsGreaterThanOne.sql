
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
	USE [FISDataMart]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[usp_GetEmployeesWithFTEAmountsGreaterThanOne] @FiscalYear = 2020

	SELECT	'Return Value' = @return_value

	GO
*/
-- Modifications:
--	20160816 by kjt: Revised to use [dbo].[AnotherLaborTransactions] 
--	20201020 by kjt: Revised to handle NULL PayPeriodEndDates present in
--		Fringe transactions of UC Path data, plus added ReportingYear to 
--		WHERE clause as multiple reporting years may be present.
-- 
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetEmployeesWithFTEAmountsGreaterThanOne] 
(	
	@FiscalYear int = 2020,
	@IsDebug bit = 0
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SELECT *, CASE WHEN [ExcludedByARC] = 0 THEN FTE ELSE 0 END AS InclFTE  
	--INTO EmployeesWithFTEAmountsGreaterThanOne_2020
	FROM (
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
		CASE 
			WHEN [FinanceDocTypeCd] IN (SELECT DocumentType FROM dbo.[FinanceDocTypesForFTECalc]) AND
				 ObjConsol IN (SELECT Obj_Consolidatn_Num FROM dbo.[ConsolCodesForFTECalc]) AND 
				 DosCd IN (SELECT DOS_Code FROM dbo.DOSCodes) AND
				 [PayRate] <> 0
			THEN 
				CASE 
					WHEN [RateTypeCd] = 'H' 
					THEN SUM(Amount) / ([PayRate] * 2088) 
					ELSE SUM(Amount) / [PayRate] / 12 
				END 
			ELSE 0 
		END
		AS FTE
	FROM
		[dbo].[AnotherLaborTransactions] 
	WHERE
		ReportingYear = @FiscalYear AND
		EmployeeID IN (	SELECT
							DISTINCT [EmployeeID] 
						FROM
							(	SELECT
									[EmployeeID] ,
									[EmployeeName] ,
									CONVERT(DECIMAL(18, 4),
									CASE 
										WHEN 
											[FinanceDocTypeCd] IN (SELECT DocumentType FROM dbo.[FinanceDocTypesForFTECalc]) AND
											ObjConsol IN (SELECT Obj_Consolidatn_Num FROM dbo.[ConsolCodesForFTECalc]) AND
											DosCd IN (SELECT DOS_Code FROM dbo.DOSCodes) AND
											[PayRate] <> 0 
										THEN 
											CASE 
												WHEN [RateTypeCd] = 'H' 
												THEN SUM(Amount) / ([PayRate] * 2088) 
												ELSE SUM(Amount) / [PayRate] / 12 
											END 
										ELSE 0 
									END) AS FTE 
								FROM
									[dbo].[AnotherLaborTransactions] 
								WHERE
									ExcludedByOrg = 0 AND
									ExcludedByARC = 0 
								GROUP BY
									[EmployeeID] ,
									[EmployeeName],
									FinanceDocTypeCd,
									ObjConsol,
									Payrate,
									RateTypeCd,
									DOScd ) t1 
						GROUP BY
							[EmployeeID] ,
							[EmployeeName] 
						HAVING
							SUM(FTE) > 1.001 ) AND
							ObjConsol IN (SELECT Obj_Consolidatn_Num FROM dbo.[ConsolCodesForFTECalc]) AND
							DosCd IN	 (SELECT DOS_Code FROM dbo.DOSCodes) 
	GROUP BY
		[PayPeriodEndDate],
		[Chart] ,
		[Account] ,
		[Org] ,
		[ObjConsol] ,
		[FinanceDocTypeCd] ,
		[DosCd] ,
		[EmployeeID] ,
		[EmployeeName] ,
		[TitleCd] ,
		[AnnualReportCode] ,
		[ExcludedByARC] ,
		[ExcludedByOrg] ,
		[ExcludedByAccount],
		[Payrate],
		[RateTypeCd] 
		) t1
	ORDER BY
		[EmployeeName] ,
		[EmployeeID] ,
		[PayPeriodEndDate],
		[TitleCd] ,
		[Chart] ,
		[Org] ,
		[ExcludedByAccount],
		[Account] ,
		[ObjConsol] ,
		[FinanceDocTypeCd] ,
		[DosCd] ,
		[AnnualReportCode] ,
		[ExcludedByARC] ,
		[ExcludedByOrg] ,
		[PayRate] ,
		[RateTypeCd]
END