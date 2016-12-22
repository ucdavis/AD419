-- =============================================
-- Author:		Ken Taylor
-- Create date: November 18, 2016
-- Description:	Generate the SQL used in the CASE state for updating NewAccountSFN's SFN.
-- This procedure basically takes the place of the hard-coded CASE statement
-- by using the values present in the new SfnClassificationLogic table, so it can be
-- maintained via a UI in the AD-419 Data Helper application.
--
-- Usage:
/*
	USE AD419
	GO

	DECLARE @CaseStatement varchar(MAX) 
	EXEC usp_GenerateNewAccountSfnCaseStatement @CaseStatement OUTPUT

	PRINT 'CASE Statement: ' + @CaseStatement
	GO
*/
--
-- Modifications:
-- 
CREATE PROCEDURE [dbo].[usp_GenerateNewAccountSfnCaseStatement]
( @CaseStatement varchar(MAX) OUTPUT)
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	/*
	Build the SFN classification CASE statement SQL based on data present in the [dbo].[SfnClassificationLogic] table.
	*/

	DECLARE @OldEvaluationOrder int, @OldParameterOrder int, @OldSubParameterOrder int, @OldSFN varchar(5)

	DECLARE @CASE_SQL varchar(MAX) = 'CASE '

	DECLARE myCursor CURSOR FOR 

	SELECT [EvaluationOrder]
		  ,[ParameterOrder]
		  ,[SubParameterOrder]
		  ,[LogicalOperator]
		  ,[ColumnName]
		  ,[NegateCondition]
		  ,[ConditionalOperator]
		  ,[Values]
		  ,REPLACE(SFN, CHAR(13)+CHAR(10),'') SFN  -- Some of the SFNs got added with CRLF.  We need to remove these just in case.
	  FROM [AD419].[dbo].[SfnClassificationLogic]
	  order by EvaluationOrder, ParameterOrder, SubParameterOrder
	
	  DECLARE @EvaluationOrder int
		  ,@ParameterOrder int
		  ,@SubParameterOrder int
		  ,@LogicalOperator varchar(5)
		  ,@ColumnName varchar(500)
		  ,@NegateCondition bit
		  ,@ConditionalOperator varchar(10)
		  ,@Values varchar(2048)
		  ,@SFN varchar(5)

	OPEN myCursor
	FETCH NEXT FROM myCursor INTO  @EvaluationOrder 
		  ,@ParameterOrder
		  ,@SubParameterOrder 
		  ,@LogicalOperator
		  ,@ColumnName
		  ,@NegateCondition
		  ,@ConditionalOperator
		  ,@Values
		  ,@SFN

	SELECT @OldEvaluationOrder = @EvaluationOrder,@OldParameterOrder = @ParameterOrder , @OldSubParameterOrder = @SubParameterOrder, @OldSFN = @SFN
	DECLARE @ClosingParenthesisCount int = 0

	WHILE @@FETCH_STATUS <> -1
	BEGIN
		IF @LogicalOperator IS NOT NULL
		BEGIN
			SELECT @CASE_SQL += ' ' + @LogicalOperator + ' '

			IF (@SubParameterOrder IS NOT NULL AND @OldSubParameterOrder IS NULL) OR
			(@OldParameterOrder != @ParameterOrder AND @OldSubParameterOrder IS NOT NULL) 
			BEGIN
				-- Add Opening parenthesis:
				SELECT @CASE_SQL += '('
				SELECT @ClosingParenthesisCount += 1
			END

			SELECT @CASE_SQL += @ColumnName
		END
		ELSE
		BEGIN
		-- Start the beginning of new WHEN branch:
			SELECT @ClosingParenthesisCount = 0
			SELECT @CASE_SQL += '
		WHEN '
			IF @OldEvaluationOrder != @EvaluationOrder AND @SubParameterOrder IS NOT NULL
			BEGIN
				SELECT @CASE_SQL += '('
				SELECT @ClosingParenthesisCount += 1
			END
			SELECT @CASE_SQL += @ColumnName 
		END

		IF @Values = 'NULL' 
		BEGIN
			-- Handle using an 'IS' instead of an '=' sign if the value to compare against is NULL:
			SELECT @CASE_SQL += ' IS'
			IF @NegateCondition IS NOT NULL AND @NegateCondition = 1
			BEGIN
				SELECT @CASE_SQL += ' NOT'
			END
			SELECT @CASE_SQL += ' ' + @Values
		END
		ELSE
		BEGIN
			IF @NegateCondition IS NOT NULL AND @NegateCondition = 1
			BEGIN
				-- Handle using a ! for equals statements instead of a NOT
				IF @ConditionalOperator = '='
				BEGIN
					SELECT @CASE_SQL += ' !'
				END
				ELSE
				BEGIN
					-- Otherwise use a 'NOT'
					SELECT @CASE_SQL += ' NOT'
				END
			END
	
			SELECT @CASE_SQL += ' '+ @ConditionalOperator
			IF @ConditionalOperator = 'IN'
			BEGIN
				-- Handle adding opening and closing parenthesis around 'IN' values:
				SELECT @CASE_SQL += ' (' + @Values + ')'
			END
			ELSE
				BEGIN
					SELECT @CASE_SQL += ' ' + @Values
				END
		END
	
		SELECT @OldEvaluationOrder = @EvaluationOrder, @OldParameterOrder = @ParameterOrder, @OldSubParameterOrder = @SubParameterOrder,  @OldSfn = @SFN

		FETCH NEXT FROM myCursor INTO  @EvaluationOrder 
		  ,@ParameterOrder
		  ,@SubParameterOrder 
		  ,@LogicalOperator
		  ,@ColumnName
		  ,@NegateCondition
		  ,@ConditionalOperator
		  ,@Values
		  ,@SFN

		IF @OldEvaluationOrder = @EvaluationOrder AND
		@OldParameterOrder != @ParameterOrder AND
		@OldSubParameterOrder IS NOT NULL AND @SubParameterOrder IS NOT NULL AND
		@OldSubParameterOrder != @SubParameterOrder
		BEGIN
			-- Handles closing parenthesis in the middle of a statement:
			IF @OldSubParameterOrder IS NOT NULL
			BEGIN
				SELECT @CASE_SQL += ')'
				SELECT @ClosingParenthesisCount += -1
			END
		END

		IF @OldEvaluationOrder != @EvaluationOrder OR @@FETCH_STATUS = -1
		BEGIN
			-- Add Closing Parenthesis to logical units if part of a set:
			IF @OldSubParameterOrder IS NOT NULL
			BEGIN
				WHILE @ClosingParenthesisCount > 0
				BEGIN
					SELECT @CASE_SQL += ')'
					SELECT @ClosingParenthesisCount += -1
				END
			END
			-- Add 'THEN' + @OldSFN as the end of the WHEN branch
			SELECT @CASE_SQL += ' THEN ' +  master.dbo.udf_CreateQuotedStringList(1, @OldSFN,',')  
		END
	END

	-- Close the CASE statement:
	SELECT @CASE_SQL += '
		ELSE NULL
	END'

	CLOSE myCursor
	DEALLOCATE myCursor

	SELECT @CaseStatement = @CASE_SQL
END