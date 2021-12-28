
-- =============================================
-- Author:		Ken Taylor
-- Create date: October 13, 2020
--
-- Description:	Builds and returns a single or "double" single quoted list of Chart-Account numbers such as
--	'3-AEXNPDN','3-ALVCOMP','3-ALVEXPL','3-ALVGCLS','3-ANSATJH', ... or 
--	''3-AEXNPDN'',''3-ALVCOMP'',''3-ALVEXPL'',''3-ALVGCLS'',''3-ANSATJH'', ...
--	 to be used within a SQL statement's WHERE clause's "IN" clause, i.e., "WHERE DEPTID_CF IN (Chart-Account list goes here>)".
--
-- Usage:
/*
	USE [AD419]
	GO

	SELECT [dbo].[udf_ChartAccountString] (1) --Returns single quoted string, i.e., '3-AEXNPDN','3-ALVCOMP','3-ALVEXPL','3-ALVGCLS','3-ANSATJH',...
	GO

  -- OR --

	USE [AD419]
	GO

	SELECT [dbo].[udf_ChartAccountString] (0)  --(DEFAULT) --Returns a double single quoted string, i.e., ''3-AEXNPDN'',''3-ALVCOMP'',''3-ALVEXPL'',''3-ALVGCLS'',''3-ANSATJH'', ...

	GO
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION [dbo].[udf_ChartAccountString] 
(
	@UseSingleQuotes bit = 0 --Assume that the Chart-Account list is not going to be used in an SQL statement executed directly from the query window,
							 --	 but used for creating an SQL statement that is executed from within a stored procedure or function by default. 
)
RETURNS varchar(MAX)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ChartAccounts varchar(MAX) = ''

	DECLARE @temp varchar(20) = '';
	DECLARE @SingleQuote varchar(4) = ''''; -- Use this as the text qualifier when creating an ARC codes list for use within
											--   an OPENQUERY/Pass-thru that is executed directly from a query window, as opposed to a TSQl string.

	DECLARE @DoubleSingleQuotes varchar(6) = ''''''; -- Use these as the text qualifiers when creating an ARC codes list for use within
													 --   an OPENQUERY/Pass-thru query INSIDE an SQL string that is to be executed, as in "EXEC(@TSQL)".

	DECLARE @TextQualifier varchar(10) = @DoubleSingleQuotes
	IF @UseSingleQuotes = 1 
		SELECT @TextQualifier = @SingleQuote

	DECLARE MyCursor CURSOR FOR SELECT Chart + '-' + Account FROM [dbo].[AllAccountsFor204Projects] FOR READ ONLY

	OPEN MyCursor

	FETCH NEXT FROM MyCursor INTO @temp
	-- Build the ARC codes list:
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ChartAccounts +=  @TextQualifier + @temp + @TextQualifier
		FETCH NEXT FROM MyCursor INTO @temp
    
    	IF @@FETCH_STATUS = 0
    		SELECT @ChartAccounts += ', ' 
	END

	CLOSE MyCursor
	DEALLOCATE MyCursor

	RETURN @ChartAccounts
END