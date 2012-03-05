-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-July-12
-- Description:	This sproc will return all of totals for all of the appropriations
-- expenses, and encumbrances for the fiscal year provided for all of the chart(s),
-- Expense categories/Function types, i.e. CE, IR, and OR, provided,
-- With or without pending transactions, and
-- with or without Contract and Grants carry forward balances.
-- The default settings are for 2009 ORES without pending transactions and with C&G carry forward balances,
-- since this appears to be the dafault settings for a similar DaFIS report.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetCGCarryForwardBalances]
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009, -- The desired fiscal year
	@IncludeChart3 bit = 1, -- Whether to include chart 3 (1 true; 0 false) default = true
	@IncludeChartL bit = 0, -- Whether to include chart L (1 true; 0 false); default = false
	@IncludeCE bit = 0,		-- Whether to include CE expenses (1 true; 0 false); default = false
	@IncludeIR bit = 0,		-- Whether to include IR expenses (1 true; 0 false); default = false
	@IncludeOR bit = 1,		-- Whether to include OR expenses (1 true; 0 false); default = true
	
	@IncludeCGCarryForwardBalances bit = 1, -- Whether to include Contract & Grants Carry Forward Balance amounts (1 true; 0 false); default = true
	@IncludeGrandTotals bit = 1 -- Whether or not to include the Grand Totals at the bottom of the report.
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    /*
   -- Params for cutting and pasting code into query window.
   -- Commented out for sproc as these params are passed in.
	DECLARE @FiscalYear int = 2009
	DECLARE @IncludeChart3 bit = 1
	DECLARE @IncludeChartL bit = 0
	DECLARE @IncludeCE bit = 0
	DECLARE @IncludeIR bit = 0
	DECLARE @IncludeOR bit = 1
	DECLARE @IncludePending bit = 0
	DECLARE @IncludeCGCarryForwardBalances bit = 1
	DECLARE @IncludeGrandTotals bit = 1
	*/
	
	 -- Insert statements for procedure here

	DECLARE @ChartsTable TABLE(chart varchar(2))
	IF @IncludeChart3 = 1 INSERT INTO @ChartsTable VALUES('3')
	IF @IncludeChartL = 1 INSERT INTO @ChartsTable VALUES('L')

	DECLARE @HigherEdFuncCodeTable TABLE(HigherEdFunctionCode varchar(4))
	IF @IncludeCE = 1 INSERT INTO @HigherEdFuncCodeTable VALUES('PBSV')
	IF @IncludeIR = 1 INSERT INTO @HigherEdFuncCodeTable VALUES('INST'), ('FINA')
	IF @IncludeOR = 1 INSERT INTO @HigherEdFuncCodeTable VALUES('ORES')

	Declare @MyTable TABLE (SubFundGroupNum char(6), Approp decimal(14,2), Expend decimal (14,2), Encumb decimal (14,2), Balance decimal (14,2))

	------------------------------------------------------------------------------------
	-- Attempt to add/subtract the CG balance forward from the prior year:

	If @IncludeCGCarryForwardBalances = 1
	BEGIN
		DECLARE @MyCGBalanceTable TABLE (SubFundGroupNum char(6), Approp decimal (14,2), Expend decimal (14,2))

		Insert into @MyCGBalanceTable (SubFundGroupNum, Approp, Expend)
		SELECT  
			  Accounts.SubFundGroupNum,
			  SUM([YearContractsAndGrantsBeginningBalance] ) Approp,   
			 (SUM([YearContractsAndGrantsBeginningBalance] ) * -1) Expend
		FROM [FISDataMart].[dbo].[GeneralLedgerPeriodBalances] GL
		  --INNER JOIN [FISDataMart].[dbo].[SubFundGroupTypes] ON GL.SubFundGroupType = [SubFundGroupTypes].SubFundGroupType AND [ContractsAndGrantsFlag] = 'Y'
		  INNER JOIN [FISDataMart] .[dbo].[Accounts] ON GL.Account = Accounts.Account AND GL.Year = Accounts.Year AND GL.Period = Accounts.Period AND GL.Chart = Accounts.Chart
		where (YearContractsAndGrantsBeginningBalance <> 0 )
		  AND GL.Year = @FiscalYear AND GL.Chart IN (Select * from @ChartsTable)
		  AND HigherEdFuncCode  IN (Select * from @HigherEdFuncCodeTable)
		  AND BalType = 'CB' -- Current balance, i.e. approp. 
		  GROUP BY  Accounts.SubFundGroupNum
			  ,  BalType
		  ORDER BY Accounts.SubFundGroupNum
		      
		   
		DECLARE MyCGBalanceCursor CURSOR FOR Select SubFundGroupNum, Approp, Expend FROM @MyCGBalanceTable
		DECLARE @SubFundGroupNum2 char(6), @Approp2 decimal (14,2), @Expend2 decimal (14,2)

		OPEN MyCGBalanceCursor
		FETCH NEXT FROM MyCGBalanceCursor INTO @SubFundGroupNum2 , @Approp2 , @Expend2

		WHILE @@FETCH_STATUS <> -1

			BEGIN
				INSERT INTO @MyTable (SubFundGroupNum, Approp, Expend)
				VALUES (@SubFundGroupNum2, @Approp2, @Expend2)
				
				FETCH NEXT FROM MyCGBalanceCursor INTO @SubFundGroupNum2 , @Approp2 , @Expend2
			END
			
		CLOSE MyCGBalanceCursor
		DEALLOCATE MyCGBalanceCursor
	END
	------------------------------------------------------------------------------------

	UPDATE @MyTable SET Balance = ISNULL(Approp,0) + ISNULL(Expend,0) + ISNULL(Encumb,0)

    If @IncludeGrandTotals = 1
		BEGIN
			Insert INTO @MyTable (SubFundGroupNum, Approp) Values ('Totals', (Select Sum(Approp) from @MyTable))
			Update @MyTable Set Expend = (Select Sum(Expend) from @MyTable) WHERE SubFundGroupNum = 'Totals'
			Update @MyTable Set Encumb =  (Select Sum(Encumb) from @MyTable)  WHERE SubFundGroupNum = 'Totals'
			Update @MyTable Set Balance = (Select Sum(Balance) from @MyTable) WHERE SubFundGroupNum = 'Totals'
		END
		
	Select SubFundGroupNum, ISNULL(Approp,0) Approp, ISNULL(Expend,0) Expend, ISNULL(Encumb,0) Encumb, ISNULL(Balance,0) Balance FROM @MyTable
	where   Approp <>0 OR  Expend <> 0 OR Encumb <> 0
END
