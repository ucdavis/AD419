-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-July-07
-- Description:	This sproc will return all of totals for all of the appropriations
-- expenses, and encumbrances for the fiscal year provided for all of the chart(s),
-- Expense categories/Function types, i.e. CE, IR, and OR, provided,
-- With or without pending transactions, and
-- with or without Contract and Grants carry forward balances.
-- The default settings are for 2009 ORES without pending transactions and with C&G carry forward balances,
-- since this appears to be the dafault settings for a similar DaFIS report.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Get_Ap_Ex_and_En_Totals_By_SubFundGroup]
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009, -- The desired fiscal year
	@IncludeChart3 bit = 1, -- Whether to include chart 3 (1 true; 0 false) default = true
	@IncludeChartL bit = 0, -- Whether to include chart L (1 true; 0 false); default = false
	@IncludeCE bit = 0,		-- Whether to include CE expenses (1 true; 0 false); default = false
	@IncludeIR bit = 0,		-- Whether to include IR expenses (1 true; 0 false); default = false
	@IncludeOR bit = 1,		-- Whether to include OR expenses (1 true; 0 false); default = true
	@IncludePending bit = 0,-- Whether to include Pending transactions (1 true; 0 false); default = false
	@IncludeCGCarryForwardBalances bit = 1, -- Whether to include Contract & Grants Carry Forward Balance amounts (1 true; 0 false); default = true
	@IncludeGrandTotals bit = 1, -- Whether or not to include the Grand Totals at the bottom of the report.
	@IsCAES tinyint = 3 -- 1 AAES without ACBS; 2 ACBS only; 3 AAES and ACBS.
	
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
	DECLARE @IsCAES tinyint = 3
	*/
	
	 -- Insert statements for procedure here

	DECLARE @ChartsTable TABLE(chart varchar(2))
	IF @IncludeChart3 = 1 INSERT INTO @ChartsTable VALUES('3')
	IF @IncludeChartL = 1 INSERT INTO @ChartsTable VALUES('L')

	DECLARE @HigherEdFuncCodeTable TABLE(HigherEdFunctionCode varchar(4))
	IF @IncludeCE = 1 INSERT INTO @HigherEdFuncCodeTable VALUES('PBSV')
	IF @IncludeIR = 1 INSERT INTO @HigherEdFuncCodeTable VALUES('INST'), ('FINA')
	IF @IncludeOR = 1 INSERT INTO @HigherEdFuncCodeTable VALUES('ORES')
	
	DECLARE @OPAccountNumsTable TABLE(OPAccountNumPrefix varchar(2))
	IF @IncludeCE = 1 INSERT INTO @OPAccountNumsTable VALUES('62')
	IF @IncludeIR = 1 INSERT INTO @OPAccountNumsTable VALUES('40'), ('41'), ('42'), ('43')
	IF @IncludeOR = 1 INSERT INTO @OPAccountNumsTable VALUES('44'), ('45'), ('46'), ('47'), ('48'), ('49'), ('50'), ('51'), ('52'), ('53'), ('54'), ('55'), ('56'), ('57'), ('58'), ('59')

	DECLARE @SourceTableCodes TABLE(SrcTblCd char(1))
	INSERT INTO @SourceTableCodes VALUES ('A')
	IF @IncludePending = 1 INSERT INTO @SourceTableCodes VALUES('P')
	
	-- New logic to handle ACBS
    DECLARE @CAESList TABLE (IsCAES tinyint)
    IF @IsCAES = 1 OR @IsCAES = 3
	    BEGIN
		    -- CAES excluding ACBS
		    Insert into @CAESList (IsCAES) VALUES (1)
	    END
    IF @IsCAES = 2 OR @IsCAES = 3
	    BEGIN
		    -- ACBS only
		    Insert into @CAESList (IsCAES) VALUES (2)
	    END

	Declare @MyTable TABLE (SubFundGroupNum char(6), Approp decimal(14,2), Expend decimal (14,2), Encumb decimal (14,2), Balance decimal (14,2))

	Declare MyCursor CURSOR FOR select  SubFundGroupNum, BalType, 
	CASE WHEN BalType = 'CB' THEN SUM(LineAmount) END AS Approp,
	CASE WHEN BalType = 'AC' THEN SUM(LineAmount) END AS Expend,
	CASE WHEN BalType IN ('EX', 'IE') THEN SUM(LineAmount) END AS Encumb
	from 
	TransV inner join Accounts ON TransV.AccountsFK = Accounts.AccountPK -- takes 0:01:06 to run
	--TransV.Year = Accounts.Year and TransV.Chart = Accounts.Chart AND TransV.Account = Accounts.Account AND Accounts.Period = '--' -- takes 02:57 to run
	where TransV.Year = @FiscalYear and TransV.Chart IN (Select * from @ChartsTable) and 
	(HigherEdFuncCode IN (Select * from @HigherEdFuncCodeTable) OR LEFT(A11AcctNum,2) IN (SELECT * FROM @OPAccountNumsTable))
	AND TransV.IsCAES IN (SELECT * FROM @CAESList)
	AND BalType Not IN ('NB')
	AND SrcTblCd IN (Select * from @SourceTableCodes)

	GROUP BY SubFundGroupNum, BalType
	Order by SubFundGroupNum, BalType

	DECLARE @SubFundGroupNum char(6), @BalType varchar(2), @Approp decimal (14,2), @Expend decimal (14,2), @Encumb decimal (14,2)

	Open MyCursor 
	Fetch NEXT FROM MyCursor INTO @SubFundGroupNum, @BalType, @Approp,  @Expend, @Encumb

	While (@@FETCH_STATUS <> -1)
	BEGIN

	Declare @count int = (select COUNT(*) from @MyTable where SubFundGroupNum = @SubFundGroupNum)

	If @Count = 0
	BEGIN
		INSERT INTO @MyTable (SubFundGroupNum) VALUES (@SubFundGroupNum)
	END

	IF @BalType = 'AC' 
	BEGIN
	   UPDATE @MyTable Set Expend = ISNULL(@Expend,0) WHERE SubFundGroupNum = @SubFundGroupNum
	END
	ELSE IF @BalType = 'CB'
	BEGIN
		UPDATE @MyTable Set Approp = ISNULL(@Approp,0) WHERE SubFundGroupNum = @SubFundGroupNum
	END
	ELSE IF @BalType IN ('EX', 'IE')
	BEGIN
		UPDATE @MyTable Set Encumb = ISNULL(Encumb,0) + ISNULL(@Encumb,0) WHERE SubFundGroupNum = @SubFundGroupNum
	END

	Fetch NEXT FROM MyCursor INTO @SubFundGroupNum, @BalType, @Approp,  @Expend, @Encumb

	END
	CLOSE MyCursor
	DEALLOCATE MyCursor

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
		  AND (HigherEdFuncCode  IN (Select * from @HigherEdFuncCodeTable) OR LEFT(A11AcctNum,2) IN (SELECT * FROM @OPAccountNumsTable))
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
				UPDATE @MyTable SET Approp = ISNULL(Approp,0) + @Approp2, Expend = ISNULL(Expend,0) + @Expend2
				WHERE SubFundGroupNum = @SubFundGroupNum2 
				
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
