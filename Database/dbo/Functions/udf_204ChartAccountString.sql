
-- =============================================
-- Author:		Ken Taylor
-- Create date: October 13, 2020
--
-- Description:	Builds and returns a single or "double" single quoted list of 204 Chart-Account numbers such as
--	'3-AEXNPDN','3-ALVCOMP','3-ALVEXPL','3-ALVGCLS','3-ANSATJH', ... or 
--	''3-AEXNPDN'',''3-ALVCOMP'',''3-ALVEXPL'',''3-ALVGCLS'',''3-ANSATJH'', ...
--	 to be used within a SQL statement's WHERE clause's "IN" clause, i.e., "WHERE DEPTID_CF IN (Chart-Account list goes here>)".
--
-- Usage:
/*
	USE [AD419]
	GO

	-- Use this when the query is executed directly from the query window:
	 
	SELECT [dbo].[udf_204ChartAccountString] (1) --Returns single quoted string, i.e., '3-AEXNPDN','3-ALVCOMP','3-ALVEXPL','3-ALVGCLS','3-ANSATJH',...
	GO

  -- OR --

	USE [AD419]
	GO

	-- Use this for OPENQUERY where the query is executed directly:

	SELECT [dbo].[udf_204ChartAccountString] (2)  --(DEFAULT) --Returns a double single quoted string, i.e., ''3-AEXNPDN'',''3-ALVCOMP'',''3-ALVEXPL'',''3-ALVGCLS'',''3-ANSATJH'', ...

	GO

	-- OR --

	USE [AD419]
	GO

	-- Use this for OPENQUERY where the query is built up as a @TSQL string:

	SELECT [dbo].[udf_204ChartAccountString] (4)  --(DEFAULT) --Returns a double, double single quoted string, i.e., ''''3-AEXNPDN'''',''''3-ALVCOMP'''',''''3-ALVEXPL'''',''''3-ALVGCLS'''',''''3-ANSATJH'''', ...

	GO
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION [dbo].[udf_204ChartAccountString] 
(
	@NumSingleQuotes int = 4 --Assume that the Chart-Account list is not going to be used in an SQL statement executed directly from the query window,
							 --	 but used for creating a SQL statement that is built up as part of a @TSQL expression and then used in a pass-thru/OPENQUERY,
							 --	 which is executed from within a stored procedure by default. 
)
RETURNS varchar(MAX)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ChartAccounts varchar(MAX) = ''

	DECLARE @temp varchar(20) = '';
	DECLARE @SingleQuote varchar(4) = ''''; -- Use this as the base text qualifier when creating an Chart-Account numbers list for use within a WHERE clause.

	DECLARE @TextQualifier varchar(12) = REPLICATE(@SingleQuote, @NumSingleQuotes)

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