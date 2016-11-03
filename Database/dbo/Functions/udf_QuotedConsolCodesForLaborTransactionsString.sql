-- =============================================
-- Author:		Ken Taylor
-- Create date: August 1st, 2016
-- Description:	Builds and returns a NumSingleQuotes quoted list of Object Consolidation codes such as
-- ''ACAD'', ''ACAX'', ''ACGA'', ''SB01'', 
-- ''SB02'', ''SB03'',  ''SB04'',  ''SB05'',  ''SB06'',  ''SB07'',  'SB28'', 
-- ''SCHL'',  ''SUB6'', ''SUBG'', ''SUBS'',  ''SUBX'', etc
--	to be used within a SQL statement's WHERE clause's "IN" clause, i.e., "WHERE ObjConsol IN (<Consolidation codes list goes here>)".
-- Usage:
-- SELECT dbo.udf_QuotedConsolCodesForLaborTransactionsString(1) -- Returns single quoted string, i.e. '430200', '440201', '440205', '440210', '440211', '440219', '440221', '440222', ...
-- SELECT dbo.udf_QuotedConsolCodesForLaborTransactionsString(DEFAULT/2) --Returns a double single quoted string, i.e. ''430200'', ''440201'', ''440205'', ''440210'', ''440211'', ...
-- SELECT dbo.udf_QuotedConsolCodesForLaborTransactionsString(4) --Returns a double, double single quoted string, i.e. ''''430200'''', ''''440201'''', ''''440205'''', ''''440210'''', ...
--	The final example is for use within an OPENQUERY TSQL String.
-- =============================================
CREATE FUNCTION [dbo].[udf_QuotedConsolCodesForLaborTransactionsString] 
(
	@NumSingleQuotes tinyint = 2--Assume that the ARC codes list is not going to be used in an SQL statement executed directly from the query window,
								-- but used for creating an SQL statement that is executed from within a stored procedure or function by default. 
)
RETURNS varchar(MAX)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ConsolidationCodes varchar(MAX) = ''

	DECLARE @temp varchar(20) = '';
	DECLARE @SingleQuote varchar(4) = ''''; -- Use this as the text qualifier when creating an ARC codes list for use within
											--   an OPENQUERY/Pass-thru that is executed directly from a query window, as opposed to a TSQL string.

	DECLARE @DoubleSingleQuotes varchar(6) = ''''''; -- Use these as the text qualifiers when creating an ARC codes list for use within
													 --   an OPENQUERY/Pass-thru query INSIDE an SQL string that is to be executed, as in "EXEC(@TSQL)".

	DECLARE @TextQualifier varchar(10) = @SingleQuote
	DECLARE @QuoteCount smallint = 1 
	WHILE @QuoteCount < @NumSingleQuotes
	BEGIN
		SELECT @TextQualifier += @SingleQuote
		SELECT @QuoteCount = @QuoteCount + 1
	END
	

	DECLARE MyCursor CURSOR FOR SELECT Obj_Consolidatn_Num FROM [dbo].[ConsolCodesForLaborTransactions] FOR READ ONLY

	OPEN MyCursor

	FETCH NEXT FROM MyCursor INTO @temp
	-- Build the Consolidation codes list:
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ConsolidationCodes +=  @TextQualifier + @temp + @TextQualifier
		FETCH NEXT FROM MyCursor INTO @temp
    
    	IF @@FETCH_STATUS = 0
    		SELECT @ConsolidationCodes += ', ' 
	END

	CLOSE MyCursor
	DEALLOCATE MyCursor

	RETURN @ConsolidationCodes
END