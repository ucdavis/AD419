



-- =============================================
-- Author:		Ken Taylor
-- Create date: August 14, 2017
-- Description:	Populate the AccountPI table based on PI_Names pulled from accounts 
--		present in the NewAccountSFN table joinined with accounts.  

-- Notes: This verson
--		relies on the Employee ID to pull first and middle names from the 
--		PPSDataMart.dbo.Persons and AD419.dbo.UCD_PERSON's tables instead
--		of parsing the FirstMiddle name field.
-- 
-- Prerequisites:
--	We must have loaded the NewAccountSFN table prior to runing this script.
--
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateAccountPI_v3]
		@FiscalYear = 2020,
		@IsDebug = 0

GO

*/
-- Modifications:
--	2019119 by kjt: Revised comments from FISDataMart.dbo.Persons to PPSDataMrt.dbo.Persons as appropriate.
--	20201019 by kjt: Revised to use PPSDataMrt.dbo.RICE_UC_KRIM_PERSON_V instead of PPSDataMrt.dbo.Persons
--	20201104 by kjt: Totally revised to just do matching on PrincipalInvestigatorIDs and
--	PPS_IDs to elminate incorrect matches on employee names.
-- 
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateAccountPI_v3] 
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	DECLARE @AccountPI TABLE (PI_Name varchar(100), LastName varchar(50), FirstMiddle varchar(50), FirstName varchar(50), MiddleName varchar(25), EmployeeID varchar(10), PrincipalInvestigatorID varchar(10), PPS_EmployeeID varchar(10))

	-- Populate table with data found in the current NewAccountSFN table:

	INSERT INTO  @AccountPI (PI_Name, PrincipalInvestigatorID, EmployeeID, PPS_EmployeeID)
	SELECT DISTINCT
		PrincipalInvestigatorName PI_Name,
		PrincipalInvestigatorID,
		CASE WHEN 
			MAX(t4.EMPLID) IS NOT NULL AND 
			(
				(MAX(t4.EMPLID) <> MAX(t3.PPS_ID)) OR
				(MAX(t3.PPS_ID) IS NULL)
			) THEN MAX(t4.EMPLID) 
		ELSE CASE WHEN 
			MAX(t3.Employee_ID) IS NOT NULL AND 
			(
				(MAX(t3.Employee_ID) <> MAX(t3.PPS_ID)) OR  
				(MAX(t3.PPS_ID) IS NULL)
			) THEN MAX(t3.Employee_ID)
		 END END EmployeeID,
		MAX(t3.PPS_ID) PPS_EmployeeID

	FROM [AD419].[dbo].[NewAccountSFN] t1
	INNER JOIN FISDataMart.dbo.Accounts t2 ON t1.Account = t2.Account and t1.Chart = t2.Chart AND period = ''--'' AND (Year = 2020 OR Year = 9999)
	LEFT OUTER JOIN PPSDataMart.dbo.RICE_UC_KRIM_PERSON t3 ON [COMP_ACCT_USER_ID] = PrincipalInvestigatorID 
	LEFT OUTER JOIN PS_UC_EXT_SYSTEM t4 ON t3.PPS_ID = t4.PPS_ID
		
	WHERE 
		PrincipalInvestigatorName IS NOT NULL
	GROUP BY PrincipalInvestigatorName, PrincipalInvestigatorID
	ORDER BY 1

	/*
	These were all for a person named Liu, Siwei; however, they are not the same person as their PI Ids are different.
	SWELIU, SIWEILIU, JLIUSW.  Only sweliu has a UCP Id, so we will need to remove any similarly named people in the 
	next step.

	SELECT * FROM PPSDataMart.dbo.RICE_UC_KRIM_PERSON
	WHERE [COMP_ACCT_USER_ID] IN (''SWELIU'',''SIWEILIU'',''JLIUSW'')
	*/

	-- Remove any duplicate PI_Names with the same apparent names that were not matched using 
	-- the Principal Investigator ID to COMP_USER_ACCT:

	DELETE FROM @AccountPI
	WHERE  
	EXISTS (
		SELECT DISTINCT PI_Name
		FROM @AccountPI t2
		WHERE PI_Name = t2.PI_Name
		GROUP BY t2.PI_Name 
		HAVING COUNT(*) > 1
	)
	AND EmployeeID IS NULL

	--------------------------------------------------------------------
	-- Update all of the other name fields later used for ProjectPI matching:

	UPDATE @AccountPI
	SET LastName = SUBSTRING(PI_NAME, 1, CHARINDEX('','',PI_NAME)-1),
		FirstMiddle = SUBSTRING(PI_NAME, CHARINDEX('','',PI_NAME)+1, LEN(PI_NAME)-CHARINDEX('','',PI_NAME)) 

	-- Update first and middle names using whatever''s present in the FISDataMart.dbo.RICE_UC_KRIM_PERSON_V:

	UPDATE @AccountPI
	SET FirstName = t2.FIRST_NM, MiddleName = t2.MIDDLE_NM
	FROM @AccountPI t1
	INNER JOIN PPSDataMart.dbo.RICE_UC_KRIM_PERSON t2 ON t1.EmployeeID = t2.Employee_ID

	-----------------------------------------------------------------------------------
	-- Insert records into AccountPI:

	DECLARE @UpdateDate datetime2 = GETDATE()

	MERGE dbo.AccountPI t1
	USING (
		SELECT DISTINCT
			PI_Name,
			LastName,
			FirstMiddle,
			FirstName,
			MiddleName,
			EmployeeID,
			PPS_EmployeeID,
			PrincipalInvestigatorID
		FROM  AccountPI_test
	) AccountPI_Updates ON 
		(
			(t1.EmployeeID = AccountPI_Updates.EmployeeID) OR 
			(t1.EmployeeID IS NULL AND AccountPI_Updates.EmployeeID IS NULL)
		)  AND 
		t1.PI_Name = AccountPI_Updates.PI_Name AND
		t1.PrincipalInvestigatorID = AccountPI_Updates.PrincipalInvestigatorID
	WHEN MATCHED THEN UPDATE SET 
		LastUpdateDate = CASE 
			WHEN IsExistingRecord IS NULL OR IsExistingRecord = 0
				THEN @UpdateDate 
				ELSE LastUpdateDate
			END,
		IsExistingRecord = 1,
		LastName = AccountPI_Updates.LastName,
		FirstMiddle = AccountPI_Updates.FirstMiddle,
		FirstName = AccountPI_Updates.FirstName,
		MiddleName = AccountPI_Updates.MiddleName

	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES
	(
		PI_Name,
		LastName,
		FirstMiddle,
		FirstName,
		MiddleName,
		EmployeeID,
		PPS_EmployeeID,
		PrincipalInvestigatorID,
		0,
		@UpdateDate
	)
	--WHEN NOT MATCHED BY SOURCE THEN DELETE
;

	-- Make sure that all of the Account PIs have been matched:
	SELECT * FROM AccountPI 
	WHERE EmployeeID IS NULL
	ORDER BY 1
	-- (0 row(s) affected)

'
	PRINT @TSQL
	IF @IsDebug <> 1
	BEGIN
		EXEC(@TSQL)
		SET NOCOUNT OFF;
	END
    
END