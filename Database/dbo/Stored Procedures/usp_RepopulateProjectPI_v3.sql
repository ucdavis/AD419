


-- =============================================
-- Author:		Ken Taylor
-- Create date: November 11, 2021
-- Description:	Repopulate the ProjectPI table.
-- Notes: This uses our new projects list with EmployeeID as the datasource
--		so we use the employee ID Shannon provided, and don't have to search for it.
--
-- Prerequisites:
--	The AllProjectsNew table must have been loaded.
--	The NifaProjectAccessionNumberImport table must have been loaded.
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjectPI_v3]
		@FiscalYear = 2021,
		@IsDebug = 0

--SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
-- 20211115 by kjt: Revised because we were getting multiple names for the same EmployeeID.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateProjectPI_v3]
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2021, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	DECLARE @ProjectPI TABLE (OrgR varchar(4), Inv1 varchar(50), PI varchar(50), LastName varchar(50), FirstInitial char(1), EmployeeID varchar(10),
	FirstName varchar(20))

	-- Step 1: Insert Project PIs:
	INSERT INTO @ProjectPI (OrgR, Inv1, PI, LastName, FirstName, FirstInitial, EmployeeID)
	SELECT OrgR, Inv1, PI, LastName, FirstName, LEFT(FirstName, 1) FirstInitial, EmployeeID
	FROM (
		SELECT DISTINCT 
			ROW_NUMBER() OVER (PARTITION BY t2.EmployeeID ORDER BY CASE OrgR WHEN ''AINT'' THEN 1 ELSE 2 END) MyID,
			t2.EmployeeID, FullName Inv1, REPLACE(REPLACE(FullName, ''  '' , ''''), '', '', '','') PI, 
			OrgR, LastName, FirstName
		FROM [dbo].[udf_AD419ProjectsForFiscalYearWithIgnored] (' + CONVERT(varchar(4), @FiscalYear) + ') t1
		INNER JOIN PPSdataMart.dbo.Persons t2 ON t1.EmployeeID = t2.employeeID
	) t1
	WHERE MyId = 1
	ORDER BY Inv1, OrgR
'	
	-- Step 2: Truncate and Reload the ProjectPI table:

	SELECT @TSQL += '
	TRUNCATE TABLE [dbo].[ProjectPI]
	INSERT INTO [dbo].[ProjectPI] (OrgR, Inv1, PI, LastName, FirstName, FirstInitial, EmployeeID)
	SELECT DISTINCT
		OrgR,
		Inv1,
		PI,
		LastName,
		FirstName, 
		FirstInitial,
		EmployeeID
	FROM @ProjectPI
	ORDER BY OrgR, PI 
'

	PRINT @TSQL
	IF @IsDebug <> 1
	BEGIN
		EXEC(@TSQL)
	END
;
  
END