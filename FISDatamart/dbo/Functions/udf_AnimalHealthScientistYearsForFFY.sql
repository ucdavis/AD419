




-- =============================================
-- Author:		Ken Taylor
-- Create date: August 8, 2018
-- Description:	Return a table containing the direct charged scientist years
--for the college(s) provided.
-- Usage:
/*

	USE [FISDataMart]
	GO

	DECLARE @Colleges varchar(50) = 'BIOS,AAES'
	SELECT * FROM udf_AnimalHealthScientistYearsForFFY(2020, @Colleges)

	USE [FISDataMart]
	GO

	DECLARE @Colleges varchar(50) = 'VETM'
	SELECT * FROM udf_AnimalHealthScientistYearsForFFY(2019, @Colleges)

*/
-- Modifications:
--	2019-01-18 by kjt:Removed Sub-fund group type's Federal-Funds filtering, and now filtering by a specific list of 
--		Sub-fund group types: B, C, F, H, J, L, N, P, S, V, W and X, as per Shannon.
--	2019-01-22 by kjt: Removed filtering for HEFC and A11AcctNum as per Shannon, plus added HEFC as output column.
--	2020-09-24 by kjt: Revised to use distinct LaborTransactions employee names instead of ErsEmployee  
--		since I do not think we have access this table any longer.  
--		Also commented out join since it was only being used for employee name.
--	2021-07-16 by kjt: Revised to use AnotherLaborTranactions Vs. LABOR_TRANSACTIONS, as AnotherLaborTransactions now
--		contains data for ALL employees.  Also modified to only use records with FringeBenefitSalaryCd = 'S' since these
--		are the only records that contain hourly data values <> 0.
--		Replaced calculation with pre-calculated FTE.
--	2021-07-22 by kjt: Added additional columnn using using similar logic as AD-419 FTE calc:
/*			
		CONVERT(
			DECIMAL(18,4),
			CASE 
				WHEN 
					[PayRate] <> 0 
				THEN 
					SUM(ERN_DERIVED_PERCENT)/12
				ELSE 0
		END) AS SY,
*/
--	Using the calculated FTE did not return the correct results.  However, switching over to 
--	SUM(ERN_DERIVED_PERCENT)/12 returned basically the same results as Shannon's UCP-339
--	Object 21010 analysis did.  (This logic has an additional decimal point of precision, i.e. 4 Vs. 3.)
--	2021-07-22 by kjt: Try adding op fund chart to Account join. 
-- =============================================
CREATE FUNCTION [dbo].[udf_AnimalHealthScientistYearsForFFY] 
(
	-- Add the parameters for the function here
	@FiscalYear int, 
	@Colleges varchar(50)
)
RETURNS 
@ScientistYears TABLE 
(
		UcLocCd varchar(2) NOT NULL, 
		UcFundNum varchar(6) NOT NULL, 
		Org4 varchar(4) NOT NULL, 
		Chart varchar(2) NOT NULL,
		Account varchar(7) NOT NULL, 
		SY DECIMAL(18,4) NULL,
		EmployeeId varchar(10) NULL ,
        EmployeeName varchar(150) NULL
)
AS
BEGIN
	INSERT INTO @ScientistYears
	SELECT  OpLocationCode,
		FundNum,
		Org4,
		Chart,
		Account,
		Convert(DECIMAL(18,4), SUM(SY)) SY,
		EmployeeId,
        EmployeeName
	FROM (
		SELECT 	f.Chart OpLocationCode,
				f.FundNum,
				CASE 
					WHEN oh.Org4 IN ('AAES', 'BIOS') THEN 'AAES' 
					ELSE oh.Org4 
				END Org4,
				oa.Chart,
				oa.Account,
				-- 2021-07-16 by kjt: Replaced calculation with pre-calculated FTE
				--ISNULL(CASE WHEN lt.RateTypeCd = 'H' THEN SUM(lt.Amount) / (lt.Payrate * 2088)
				--		ELSE SUM(lt.Amount) / lt.Payrate / 12 
				--	END, 0) SY,
				-- 2021-07-22 by kjt: Replaced SY calculation to use same logic as AD-419 labor calc.
				CONVERT(DECIMAL(18,4),
				CASE 
					WHEN 
						[PayRate] <> 0 
					THEN 
						SUM(ERN_DERIVED_PERCENT)/12
					ELSE 0
				END) AS SY,
				lt.EmployeeID,
				lt.EmployeeName
		FROM [dbo].[OPFund] f
		-- This join didn't provide any additional details.
		--INNER JOIN [dbo].[Awards] A ON 
		--    a.UcLocationCode = f.Chart AND
		--    a.OpFundNum = f.FundNum AND
		--    a.Year = 9999 AND
		--    a.Period = '--' AND
		--    a.CgAwardsStatusCd = 'A' 
		INNER JOIN [dbo].[Organizations] oh ON 
			oh.Org4 IN (SELECT * FROM dbo.SplitVarCharValues(@Colleges)) AND -- Be sure to enter the &Colleges param in like this "'AAES','BIOS'", meaning include the single quotes and comma. Don't include the double quotes.
			oh.Year = 9999 AND 
			oh.Period = '--' AND 
			oh.Chart = f.Chart 
		INNER JOIN [dbo].[Accounts] oa ON 
			oa.Org = oh.Org and 
			oa.Chart = oh.Chart AND 
			oa.Year = 9999 and 
			oa.Period = '--' AND 
			oa.OpFundNum = f.FundNum AND 
			oa.Chart = f.Chart
			--AND (oa.HigherEdFuncCode IN ('ORES', 'OAES') OR SUBSTRING(oa.A11AcctNum,1, 2) BETWEEN '44' AND '59')
		INNER JOIN [dbo].[SubFundGroupTypes] sfgt ON 
			sfgt.SubFundGroupType = oa.SubFundGroupTypeCode AND
			--(sfgt.FederalFundsFlag = 'Y' OR (sfgt.FederalFundsFlag = 'N' AND sfgt.SubFundGroupType = 'B'))
			sfgt.SubFundGroupType IN ('B', 'C', 'F', 'H', 'J', 'L', 'N', 'P', 'S', 'V', 'W', 'X')
		INNER JOIN [dbo].[AnotherLaborTransactions] lt ON 
			lt.Chart = oa.Chart and lt.Account = oa.Account and (ReportingYear = @FiscalYear) AND
			--LT.FIN_BALANCE_TYP_CD = 'AC' AND
			lt.object NOT IN ('0054', '0520', '9998', 'HIST') AND
			lt.TitleCd IN (SELECT TitleCode FROM [PPSDataMart].[dbo].[PI_TitleCodesV])--('0503', '1062', '1063', '1064', '1065', '1066', '1067', '1100', '1103', '1106', '1109', '1110', '1111', '1112', '1116', '1132', '1143', '1144', '1145', '1146', '1180', '1200', '1203', '1210', '1243', '1244', '1245', '1300', '1303', '1310', '1330', '1343', '1344', '1450', '1451', '1452', '1453', '1454', '1455', '1701', '1702', '1707', '1717', '1719', '1721', '1724', '1725', '1726', '1728', '1729', '1730', '1732', '1733', '1734', '1737', '1739', '1741', '1744', '1745', '1746', '1748', '1749', '1750', '1897', '1899', '1901', '1904', '1905', '1906', '1908', '1909', '1910', '1932', '1981', '1982', '1983', '1984', '1985', '1986', '1987', '1988', '1989', '1997', '2001', '2030', '2050', '2730', '3000', '3001', '3004', '3010', '3011', '3012', '3013', '3014', '3015', '3020', '3021', '3060', '3062', '3070', '3072', '3080', '3081', '3082', '3114', '3190', '3200', '3203', '3205', '3206', '3209', '3210', '3213', '3215', '3216', '3220', '3223', '3225', '3226', '3258', '3259', '3268', '3269', '3270', '3278', '3279', '3352', '3361', '3362', '3372', '3374', '3375', '3377', '3378', '3379', '3390', '3392', '3393', '3394', '3395', '3475', '3477', '3479', '3492', '3494', '3802', '3812') AND
			AND lt.[ObjConsol] IN (SELECT Obj_Consolidatn_Num FROM [dbo].[ConsolCodesForFTECalc]) --('ACAD', 'ACAX', 'ACGA', 'SB00', 'SB01', 'SB02', 'SB03', 'SB04', 'SB05', 'SB06', 'SB07', 'STFB', 'STFO', 'SUB0', 'SUBG', 'SUBS', 'SUBX') AND
			AND lt.FinanceDocTypeCd IN (SELECT DocumentType FROM [dbo].[FinanceDocTypesForFTECalc]) --('HDRW', 'OPAY', 'PAY', 'PAYC', 'SET', 'YSET') AND 
			AND lt.DosCd IN (SELECT DOS_Code FROM [dbo].[DosCodes]) --('ERT', 'FTD', 'FTO', 'FTX', 'FYS', 'HBE', 'MB1', 'MB2', 'MB3', 'MB4', 'MB5', 'MB6', 'MB7', 'MB8', 'MB9', 'MEG', 'MEO', 'RED', 'REG', 'REO', 'VEG', 'VEO', 'VEX') 
			AND lt.FringeBenefitSalaryCd = 'S'
		--LEFT OUTER JOIN [dbo].[ErsEmployee] ers ON ers.EmployeeId = lt.EmployeeID -- No longer see a need for this join since we're getting the employee name from labor transactions.
		LEFT OUTER JOIN [dbo].[udf_EmployeeNames](@FiscalYear) ers ON ers.EmployeeId = lt.EmployeeID
		WHERE
			(f.AwardEndDate >=  CONVERT(date, CONVERT(char(4), @FiscalYear -1) + '-10-01') OR f.AwardEndDate IS NULL) AND
			(f.AwardBeginDate < CONVERT(date, CONVERT(char(4), @FIscalYear)    + '-10-01') OR  f.AwardBeginDate IS NULL) AND -- Variable FiscalYear
			(f.Year IN (9999) AND f.Period = '--') 
		 GROUP BY
			f.Chart,
			f.FundNum,
			CASE 
				WHEN oh.Org4 IN ('AAES', 'BIOS') THEN 'AAES' 
				ELSE oh.Org4 
			END,
			oa.Chart,
			oa.Account,
			lt.EmployeeID,
			lt.EmployeeName,
			-- 2021-07-22 by kjt: Added payrate back because now using same FTE calc as AD-419:
			lt.Payrate
	) t1
	GROUP BY 
		OpLocationCode,
		FundNum,
		Org4,
		Chart,
		Account,
		EmployeeId,
		EmployeeName
	HAVING CONVERT(DECIMAL(18,4), SUM(SY)) <> 0
	ORDER BY 
		FundNum,
		OpLocationCode,
		Org4,
		Chart,
		Account,
		EmployeeId,
		EmployeeName
	
	RETURN 
END