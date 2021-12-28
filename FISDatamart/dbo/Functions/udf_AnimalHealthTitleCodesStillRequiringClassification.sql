
-- =============================================
-- Author:		Ken Taylor
-- Create date: July 20, 2021
-- Description:	Return a list of any title codes that still 
--	require classification in terms of Animal Heallth.
--
-- Notes: This UDF is the datasource for the 
--	"Animal Health Title Codes Still Requiring Classification" report server report.
--	
-- Usage:
/*

	USE [FISDataMart]
	GO

	DECLARE @FiscalYear int = 2020, @Colleges varchar(50) = 'AAES,BIOS,VETM'

	SELECT * FROM udf_AnimalHealthTitleCodesStillRequiringClassification(@FiscalYear, @Colleges)
	GO

*/
--
-- Modifications:
--	2021-07020 by kjt: Added filtering to remove any title code with sum(calculatedFTE) = 0
--
-- =============================================
CREATE FUNCTION [dbo].[udf_AnimalHealthTitleCodesStillRequiringClassification] 
(
	-- Add the parameters for the function here
	@FiscalYear int, 
	@Colleges varchar(30)
)
RETURNS 
@UnclassifiedTitles TABLE 
(
	TitleCd varchar(4), 
	Name varchar(150), 
	[Schools/Colleges] varchar(30)
)
AS
BEGIN
	DECLARE TitleCursor CURSOR FOR 
	SELECT distinct titleCd, Name, Org4 [School/College]
	FROM (
		SELECT 
				Org4,
				lt.TitleCd,
				ttls.Name
		FROM [dbo].[OPFund] f
		
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
			oa.OpFundNum = f.FundNum 
			
		INNER JOIN [dbo].[SubFundGroupTypes] sfgt ON 
			sfgt.SubFundGroupType = oa.SubFundGroupTypeCode AND
			sfgt.SubFundGroupType IN ('B', 'C', 'F', 'H', 'J', 'L', 'N', 'P', 'S', 'V', 'W', 'X')

		INNER JOIN [dbo].[AnotherLaborTransactions] lt ON 
			lt.Chart = oa.Chart and lt.Account = oa.Account and (ReportingYear = @FiscalYear) AND
			lt.object NOT IN ('0054', '0520', '9998', 'HIST') 
			--AND lt.TitleCd IN (SELECT TitleCode FROM [PPSDataMart].[dbo].[PI_TitleCodesV])--('0503', '1062', '1063', '1064', '1065', '1066', '1067', '1100', '1103', '1106', '1109', '1110', '1111', '1112', '1116', '1132', '1143', '1144', '1145', '1146', '1180', '1200', '1203', '1210', '1243', '1244', '1245', '1300', '1303', '1310', '1330', '1343', '1344', '1450', '1451', '1452', '1453', '1454', '1455', '1701', '1702', '1707', '1717', '1719', '1721', '1724', '1725', '1726', '1728', '1729', '1730', '1732', '1733', '1734', '1737', '1739', '1741', '1744', '1745', '1746', '1748', '1749', '1750', '1897', '1899', '1901', '1904', '1905', '1906', '1908', '1909', '1910', '1932', '1981', '1982', '1983', '1984', '1985', '1986', '1987', '1988', '1989', '1997', '2001', '2030', '2050', '2730', '3000', '3001', '3004', '3010', '3011', '3012', '3013', '3014', '3015', '3020', '3021', '3060', '3062', '3070', '3072', '3080', '3081', '3082', '3114', '3190', '3200', '3203', '3205', '3206', '3209', '3210', '3213', '3215', '3216', '3220', '3223', '3225', '3226', '3258', '3259', '3268', '3269', '3270', '3278', '3279', '3352', '3361', '3362', '3372', '3374', '3375', '3377', '3378', '3379', '3390', '3392', '3393', '3394', '3395', '3475', '3477', '3479', '3492', '3494', '3802', '3812') AND
			AND lt.[ObjConsol] IN (SELECT Obj_Consolidatn_Num FROM [dbo].[ConsolCodesForFTECalc]) --('ACAD', 'ACAX', 'ACGA', 'SB00', 'SB01', 'SB02', 'SB03', 'SB04', 'SB05', 'SB06', 'SB07', 'STFB', 'STFO', 'SUB0', 'SUBG', 'SUBS', 'SUBX') AND
			AND lt.FinanceDocTypeCd IN (SELECT DocumentType FROM [dbo].[FinanceDocTypesForFTECalc]) --('HDRW', 'OPAY', 'PAY', 'PAYC', 'SET', 'YSET') AND 
			AND lt.DosCd IN (SELECT DOS_Code FROM [dbo].[DosCodes]) --('ERT', 'FTD', 'FTO', 'FTX', 'FYS', 'HBE', 'MB1', 'MB2', 'MB3', 'MB4', 'MB5', 'MB6', 'MB7', 'MB8', 'MB9', 'MEG', 'MEO', 'RED', 'REG', 'REO', 'VEG', 'VEO', 'VEX') 
			AND lt.FringeBenefitSalaryCd = 'S'

			inner JOIN PPSDataMart.dbo.Titles ttls on lt.TitleCd = ttls.TitleCode AND StaffType IS NULL
		
		WHERE
			(f.AwardEndDate >=  CONVERT(date, CONVERT(char(4), @FiscalYear -1) + '-10-01') OR f.AwardEndDate IS NULL) AND
			(f.AwardBeginDate < CONVERT(date, CONVERT(char(4), @FIscalYear)    + '-10-01') OR  f.AwardBeginDate IS NULL) AND -- Variable FiscalYear
			(f.Year IN (9999) AND f.Period = '--')  

		Group by titleCd, ttls.Name, ORG4
		HAVING SUM(CalculatedFTE) <> 0
	) t1
	ORDER BY Org4, titleCd, Name

	DECLARE @titleCd varchar(4), @Name varchar(150), @School varchar(4)
	OPEN TitleCursor

	FETCH NEXT FROM titleCursor INTO @titleCd, @Name, @School
	WHILE @@FETCH_STATUS <> -1
	BEGIN
		DECLARE @Count smallint = (SELECT COUNT(*) FROM @UnclassifiedTitles WHERE titleCd = @TitleCd)
		IF @Count > 0
			UPDATE @UnclassifiedTitles 
			SET [Schools/Colleges] = [Schools/Colleges] + ', ' + @School
			WHERE titleCd = @TitleCd
		ELSE
			INSERT INTO @UnclassifiedTitles VALUES(@titleCd, @Name, @School)


		FETCH NEXT FROM titleCursor INTO @titleCd, @Name, @School
	END

	CLOSE titleCursor
	DEALLOCATE titleCursor

	
	RETURN 
END