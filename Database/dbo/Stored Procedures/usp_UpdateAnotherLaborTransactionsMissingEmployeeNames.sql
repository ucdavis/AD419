-- =============================================
-- Author:		Ken Taylor
-- Create date: August 20, 2016
-- Description:	Update the LaborTransactions table's missing employee names where they
--	were not found in the FINANCE.UCD_PERSON table.
--
-- Usage:
/*
	EXEC [dbo].[usp_UpdateAnotherLaborTransactionsMissingEmployeeNames]  @IsDebug = 0
*/

-- Modifications:
-- 2013-11-13 by kjt: Added apostrophe replacement for names like O'Malley, etc.
-- 2015-02-19 by kjt: Removed [AD419] specific database references so sproc could be used on other databases
-- such as AD419_2014, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateAnotherLaborTransactionsMissingEmployeeNames] 
	@IsDebug bit = 0 -- Set to 1 to print generated SQL only
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

 /*
Needed because the FINANCE.UCD_PERSON is missing names and a left outer join must be used in order to insert all of the pertainent records.
Therefore, this update must be performed to populate the missing TOE_Name fields as applicable.
*/

-- Print a list of employee IDs with whose records have NULL employee names prior to updates:
select distinct EmployeeID EIDs_with_Missing_Names
FROM dbo.AnotherLaborTransactions
WHERE EmployeeName IS NUll

--DECLARE @IsDebug bit = 0 -- Set to 1 to print generated SQL only:
DECLARE @RecordsUpdatedCount int = 0

DECLARE @MyCount int = 0 -- variable to hold rows updated per employee

DECLARE MyCursor CURSOR FOR SELECT DISTINCT P.FullName AS EmployeeName, LT.EmployeeID
FROM PPSDataMart.dbo.Persons P
INNER JOIN dbo.AnotherLaborTransactions LT ON P.EmployeeID = LT.EmployeeId
WHERE LT.EmployeeName IS NULL
ORDER BY P.FullName

DECLARE @TOE_NAME varchar(255), @EID varchar(9)
DECLARE @TSQL nvarchar(MAX) = ''
OPEN MyCursor
FETCH NEXT FROM MyCursor INTO @TOE_NAME, @EID
WHILE @@FETCH_STATUS <> -1
BEGIN
	SELECT @TSQL = '
SET NOCOUNT ON
'
-- Add RowCount variable if just printing SQL.  Not needed if executing because passed as param for sp_executesql.
	IF @IsDebug = 1
		SELECT @TSQL += '
DECLARE @RowCount int = 0
'
	SELECT @TSQL += '
UPDATE dbo.AnotherLaborTransactions
SET EmployeeName = ''' + REPLACE(@TOE_NAME, '''', '''''' ) + '''
WHERE EmployeeID = ''' + @EID + '''
SELECT @RowCount = @@RowCount
PRINT (''' + REPLACE(@TOE_NAME, '''', '''''' ) + ''' + '' ('' + ''' + @EID + ''' + ''): '' + CONVERT(varchar(5), @RowCount) + '' rows updated.'' );
'
	IF @IsDebug = 1
		BEGIN
			SET NOCOUNT ON
			PRINT @TSQL
			SET NOCOUNT OFF
		END
	ELSE
		BEGIN
			EXEC sp_executesql @TSQL, N'@RowCount int OUTPUT', @MyCount OUTPUT;
			SELECT @RecordsUpdatedCount = @MyCount + @RecordsUpdatedCount
		END

	FETCH NEXT FROM MyCursor INTO @TOE_NAME, @EID
END

CLOSE MyCursor
DEALLOCATE MyCursor

IF @IsDebug = 0
	PRINT '
Total Number of Records Updated = ' + CONVERT(varchar(50), @RecordsUpdatedCount);

SET NOCOUNT ON

-- Print a list of employee IDs with whose records have NULL employee names after updates have been completed:
select distinct EmployeeID EIDs_still_with_Missing_Names
FROM dbo.AnotherLaborTransactions
WHERE EmployeeName IS NUll


END