

-- =============================================
-- Author:		Ken Taylor
-- Create date: July 26, 2018
-- Description:	Returns the data used for the main Animal Health Expenses 
-- report for a given Federal Fiscal Year (FFY).
-- Usage:
/*
	USE [FISDataMart]
	GO

	DECLARE @Colleges varchar(50) = 'AAES,BIOS,VETM', @FiscalYear int = 2020

	SELECT * FROM udf_AnimalHealthOpFundExpensesForFFY(@FiscalYear, @Colleges)
*/
-- Modifications:
--	2018-09-28 Fixed issue with fiscal year being one behind.
--	2019-01-18 by kjt:	Removed Sub-fund group type's Federal-Funds filtering, and now filtering by a specific list of 
--		Sub-fund group types: B, C, F, H, J, L, N, P, S, V, W and X, as per Shannon.
--		Removed filtering for HEFC and A11AcctNum as per Shannon, plus added HEFC as output column.
---	2021-07-01 by kjt: Revised join on OpFundInvestigator to use chart instad of OpLocationCode as there was no such column, 
--		and this was causing
--		multiples of the total expenses based on the number of charts involved; however, ended up commenting it out
--		since it appears to no longer have any contribution to the output field list.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_AnimalHealthOpFundExpensesForFFY]
(
	-- Add the parameters for the function here
	@FiscalYear int, 
	@Colleges varchar(50) --@Colleges OrgTableType READONLY
)
RETURNS 
@AhExpenses TABLE 
(
	UcLocCd varchar(2) NOT NULL, 
	UcFundNum varchar(6) NOT NULL, 
	Org4 varchar(4) NOT NULL, 
	Chart varchar(2) NOT NULL,
	Account varchar(7) NOT NULL, 
	Expenses money NULL,
	AwardAmount money NULL,
	AwardBeginDate date NULL, 
	AwardEndDate date NULL, 
	ProjectTitle varchar(250) NULL, 
	SponsorCodeName varchar(30) NULL,
	PrimaryPIUserName varchar(124) NULL, 
	EmailAddress varchar(200) NULL,
	HigherEdFuncCode varchar(10) NULL
)
AS
BEGIN
	INSERT INTO @AhExpenses
	SELECT f.Chart AS UcLocCd, f.FundNum, CASE WHEN oh.Org4 IN ('AAES', 'BIOS') THEN 'AAES' ELSE oh.Org4 END AS Org4, 
	oa.Chart, oa.Account, ISNULL(SUM(t.LineAmount), 0) Expenses
		,f.AwardAmount
		, CONVERT(date, f.AwardBeginDate) AwardBeginDate, CONVERT(date, f.AwardEndDate) AwardEndDate, f.ProjectTitle, s.SponsorCodeName,
		PrimaryPIUserName, 
		EmailAddress,
		COALESCE(oa.HigherEdFuncCode, oa.A11AcctNum)
	FROM OPFund f
	INNER JOIN Accounts oa ON 
		oa.Chart = f.Chart and oa.OpFundNum = f.FundNum and
		oa.Year = f.Year and oa.Period = f.Period  
		-- AND (oa.HigherEdFuncCode IN ('ORES','OAES') OR SUBSTRING(oa.A11AcctNum,1, 2) BETWEEN '44' AND '59')
	INNER JOIN Organizations oh ON
		oh.Org4 IN (SELECT * FROM [dbo].[SplitVarcharValues] (
  @Colleges)) AND
		oh.Chart = oa.Chart and oh.Org = oa.Org AND
		oh.Year = oa.Year and oh.Period = oa.Period
	INNER JOIN TransV t ON
		t.Chart = oa.Chart and t.Account = oa.Account AND 
		t.Object NOT IN ('0054', '0520', '9998', 'HIST') AND
		t.BalType IN ('AC') AND
		((t.Year = (@FiscalYear) and t.Period BETWEEN '04' AND '13') OR (t.Year = @FiscalYear + 1 and t.Period BETWEEN '01' AND '03'))
	INNER JOIN SubFundGroupTypes sfgt ON
		sfgt.SubFundGroupType = oa.SubFundGroupTypeCode AND
		--(sfgt.FederalFundsFlag = 'Y' OR (sfgt.FederalFundsFlag  = 'N' AND sfgt.SubFundGroupType = 'B'))
		sfgt.SubFundGroupType IN ('B', 'C', 'F', 'H', 'J', 'L', 'N', 'P', 'S', 'V', 'W', 'X')
	LEFT OUTER JOIN Sponsors s ON s.SponsorCode = f.SponsorCode
	-- Does not appear to be used for anything at this point
	--LEFT OUTER JOIN OpFundInvestigator fi ON 
	--	fi.ResponsibleInd = 'Y' AND
	--	fi.OpLocationCode = f.Chart AND
	--	fi.OpFundNum = f.FundNum AND
	--	fi.Year = f.Year and fi.Period = f.Period
	LEFT OUTER JOIN RiceUcKrimPerson rkp2 ON
		rkp2.DaFisId = f.PrimaryPIDaFISUserId AND
		rkp2.ActiveInd = 'Y' 
	WHERE f.Year = 9999 and f.Period = '--' AND
		(f.AwardEndDate >= CONVERT(date, CONVERT(varchar(4), @FiscalYear - 1) + '1001', 112 ) OR f.AwardEndDate IS NULL) AND
		(f.AwardBeginDate < CONVERT(date, CONVERT(char(4),@FiscalYear) + '1001', 112 ) OR f.AwardBeginDate IS NULL) AND
		(f.year = 9999 AND f.period = '--') 
		--AND t.Account = 'V470BPM' AND 
		--oa.chart = '3' and oa.Account IN ('V4C2NBQ', 'V440L55','V4D1457','V431G16')
	GROUP BY
		f.FundNum,
		f.Chart,
		CASE WHEN oh.Org4 IN ('AAES', 'BIOS') THEN 'AAES' ELSE oh.Org4 END,
		oa.Chart,
		oa.Account
		,f.AwardAmount
		,f.AwardBeginDate,
		f.AwardEndDate,
		f.ProjectTitle,
		SponsorCodeName,
		PrimaryPIUserName,
		EmailAddress,
		oa.HigherEdFuncCode,
		oa.A11AcctNum
		HAVING
			ISNULL(SUM( t.LineAmount),0) != 0 
		ORDER BY
			2,
			1,
			3
	
	RETURN 
END