-- =============================================
-- Author:		Ken Taylor
-- Create date: September 16, 2016
-- Description:	Returns a list of any transactions that have non-zero expenses 
-- on Codes* that are not already in our system.
-- *Object Consolidation Codes, D.O.S. codes, and Finance Doc. Type codes.
-- Usage:
/*
	-- Option 0: All 3 types of codes (default)
	SELECT * FROM udf_GetTransactionsForUnknownCodes(0)

	-- Option 1: Obj Consolidation Codes:
	SELECT * FROM udf_GetTransactionsForUnknownCodes(1)

	-- Option 2: Finance/Trans. Doc. Type (codes) (TransDocTypes):
	SELECT * FROM udf_GetTransactionsForUnknownCodes(2)

	-- Option 3: D.O.S. (DOS) codes:
	SELECT * FROM udf_GetTransactionsForUnknownCodes(3)
*/
-- Modifications:
--	20160919 by kjt: Added inner join to trans doc types statement that excludes Obj Consol Codes not
--		used in FTE calculations to limit the number of rows returned.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetTransactionsForUnknownCodes] 
(
	@Option int = 0 -- Return the transactions for all codes. 
)
RETURNS 
@TransactionsForUnknownCodes TABLE 
(	  
	   [Chart] varchar(2)
      ,[Account] varchar(7)
      ,[SubAccount] varchar(5)
      ,[Org] varchar(4)
      ,[ObjConsol] varchar(4)
      ,[FinanceDocTypeCd] varchar(4)
      ,[DosCd] varchar(3)
      ,[EmployeeID] varchar(40)
      ,[EmployeeName] varchar(1000)
      ,[TitleCd] varchar(4)
      ,[RateTypeCd] varchar(1)
      ,[Payrate] numeric(17,4)
      ,[Amount] money
      ,[PayPeriodEndDate] datetime2(7)
      ,[FringeBenefitSalaryCd] varchar(1)
      ,[AnnualReportCode] varchar(6)
      ,[ExcludedByARC] bit
      ,[ExcludedByOrg] bit
      ,[ExcludedByAccount] bit
      ,[ExcludedByObjConsol] bit
	  ,Id int NOT NULL IDENTITY
)
AS
BEGIN
	
	IF @Option IN (0, 1)
	BEGIN
	-- Add Transactions for missing Obj Consolidation Codes:
		INSERT INTO @TransactionsForUnknownCodes (
		   [Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[FinanceDocTypeCd]
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[EmployeeName]
		  ,[TitleCd]
		  ,[RateTypeCd]
		  ,[Payrate]
		  ,[Amount]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ExcludedByOrg]
		  ,[ExcludedByAccount]
		  ,[ExcludedByObjConsol]
	  )
		SELECT t1.* FROM [AnotherLaborTransactions]  t1
		INNER JOIN (
		select distinct ObjConsol from [AnotherLaborTransactions] 
		EXCEPT 
		select  distinct Obj_Consolidatn_Num from ConsolidationCodes 
		) t2 ON t1.ObjConsol =t2.ObjConsol
		WHERE ExcludedByOrg = 0 AND ExcludedByARC = 0

		UNION

		-- Add any non-expired, UC Davis 204 accounts
		SELECT t1.* FROM [AnotherLaborTransactions]  t1
		INNER JOIN (
		select distinct ObjConsol from [AnotherLaborTransactions] 
		EXCEPT 
		select  distinct Obj_Consolidatn_Num from ConsolidationCodes 
		) t2 ON t1.ObjConsol =t2.ObjConsol
		INNER JOIN AllAccountsFor204Projects t3 ON t1.Chart = t3.Chart AND
			t1.Account = t3.Account AND t3.ExcludedByAccount = 0 AND t3.IsUCD = 1 AND
			t3.IsExpired = 0
	END

	IF @Option IN (0, 2)
	BEGIN
		-- Add Transactions for missing Finance Doc Type Codes (Trans Doc Types):
		INSERT INTO @TransactionsForUnknownCodes (
		   [Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[FinanceDocTypeCd]
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[EmployeeName]
		  ,[TitleCd]
		  ,[RateTypeCd]
		  ,[Payrate]
		  ,[Amount]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ExcludedByOrg]
		  ,[ExcludedByAccount]
		  ,[ExcludedByObjConsol]
	  )
	  SELECT t1.* FROM (
		select t1.* from [AnotherLaborTransactions] t1 
		INNER JOIN (
			select distinct FinanceDocTypeCd from [AnotherLaborTransactions] 
			EXCEPT 
			select  distinct DocumentType from TransDocTypes 
		) t2 ON t1.FinanceDocTypeCd = t2.FinanceDocTypeCd
		WHERE ExcludedByOrg = 0 AND ExcludedByARC = 0

		UNION

		-- Add any non-expired, UC Davis 204 accounts
		SELECT t1.* FROM [AnotherLaborTransactions]  t1
		INNER JOIN (
			select distinct FinanceDocTypeCd from [AnotherLaborTransactions] 
			EXCEPT 
			select  distinct DocumentType from TransDocTypes 
		) t2 ON t1.FinanceDocTypeCd = t2.FinanceDocTypeCd
		INNER JOIN AllAccountsFor204Projects t3 ON t1.Chart = t3.Chart AND
			t1.Account = t3.Account AND t3.ExcludedByAccount = 0 AND t3.IsUCD = 1 AND
			t3.IsExpired = 0) t1
	INNER JOIN ConsolCodesForFTECalc t2 ON t1.ObjConsol = t2.Obj_Consolidatn_Num --Exclude any that are not used in labor calculations.

	END

	If @Option IN (0, 3)
	BEGIN
		-- Look for any missing Finance DOS Codes:
		-- Add any within our ARCS and Orgs:
		INSERT INTO @TransactionsForUnknownCodes (
		   [Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[FinanceDocTypeCd]
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[EmployeeName]
		  ,[TitleCd]
		  ,[RateTypeCd]
		  ,[Payrate]
		  ,[Amount]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ExcludedByOrg]
		  ,[ExcludedByAccount]
		  ,[ExcludedByObjConsol]
	  )
		select t1.* from [AnotherLaborTransactions]  t1
		INNER JOIN ConsolCodesForFTECalc t2 ON t1.ObjConsol = t2.Obj_Consolidatn_Num  -- Only include transactions we use for labor calculations.
		INNER JOIN (
			select distinct DosCd from [AnotherLaborTransactions] 
			EXCEPT 
			select  distinct DOS_Code DosCd from DOS_Codes 
		) t3 ON t1.DosCd = t3.DosCd
		WHERE ExcludedByOrg = 0 AND ExcludedByARC = 0

		UNION

		-- Add any non-expired, UC Davis 204 accounts
		select t1.* from [AnotherLaborTransactions]  t1
		INNER JOIN ConsolCodesForFTECalc t2 ON t1.ObjConsol = t2.Obj_Consolidatn_Num
		INNER JOIN AllAccountsFor204Projects t3 ON t1.Chart = t3.Chart AND
			t1.Account = t3.Account AND t3.ExcludedByAccount = 0 AND t3.IsUCD = 1 AND
			t3.IsExpired = 0
		where DosCd IN (
			select distinct DosCd from [AnotherLaborTransactions] 
			EXCEPT 
			select  distinct DOS_Code DosCd from DOS_Codes 
		)
	END
		
	RETURN 
END