
-- =============================================
-- Author:		Ken Taylor
-- Create date: June 26, 2021
-- Description:	Updates any blank title codes with data from the PS_JOBS_V view.
-- Notes: The UCP 339 report uses the PS_JOB table as its source for Job code (title code) information.
--	First pass is using Emp ID, EMP RCD, and EFFDT.  Any unmatched title codes are then matched using 
--	EMP ID, EMP_RCD, and POSITION_NBR.

--
-- Usage:
/*
	USE [FISDataMart]	
	GO

	DECLARE @FiscalYear int = 2021
	DECLARE @IsDebug bit = 1
	DECLARE @TableName varchar(100) = 'AnotherLaborTransactions_Temp'

	DECLARE @Return_Value int

	EXEC usp_UpdateAnotherLaborTransactionsBlankTitleCodes
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug,
		@TableName = @TableName,
		@NumNullRecs = @Return_Value OUTPUT

	IF @IsDebug = 0
		SELECT @Return_Value AS NumNullRecs

*/
-- Modifications:
--	2021-07-16 by kjt: Revised to default to use the jobcodes present in the CAESAPP_HCMODS.PS_JOB_V table,
--		based on the highest effseq for any given date, emplid and empl_rcd.  This way we avoid issues due to 
--		job code corrections made on the same date indicated by a higher sequence numbered record.  Any
--		unmatched records are then matched by EMP_ID, EMP_RCD, and POSITION_NBR.
--	This also resets any titlecode previous set in the load script for every labor record for consistencies sake.
--	2021-07-23 by kjt: Fixed syntax errors still referring to physical BlankTitleCdRecs table.
--	2021-08-02 by kjt: Add filtering blank title code filtering on initial load of EmployeeKeyFields 
--		in-memory table in order to remove check for down-stream queries.  Also removed NULL check
--		on updates as this takes time and all title codes can be assumed to be NULL.
--	2021-09-18 by kjt: The 2021 data had a blank title code; therefore, I added 1 additional segment 
--	using just the employeeID and EMP_RCD for a match.
--	2021-08-24 by kjt: Revised usage sample above to actually return correct output value.
--  
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateAnotherLaborTransactionsBlankTitleCodes] 
	@FiscalYear int = 2021, 
	@IsDebug bit = 0,
	@TableName varchar(100) = 'AnotherLaborTransactions_Temp',
	@NumNullRecs int OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

		-- Make sure all but the appropriate indexes are disabled:
	DECLARE @IndexTable TABLE(index_name varchar(255), index_description varchar(255), index_keys varchar(255))

	INSERT INTO @IndexTable
	exec sp_helpindex @TableName

  	DECLARE @IndexName varchar(255) = (
	SELECT index_name FROM @IndexTable
	WHERE index_keys = 'EmployeeID, EFFDT(-), EMP_RCD, EFFSEQ(-)'
	)

	DECLARE @TSQL varchar(MAX) = ''

	-- Disable any non-essential indexes:
	SELECT @TSQL = '
	USE [FISDataMart]

	EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName=''' + @TableName + '''

	-- Enable index on appropriate key fields:
	ALTER INDEX [' + @IndexName + '] ON [dbo].[' + @TableName + '] REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
	-- After initial load, insert all the key fields into a temp table for every labor record:
	--DECLARE BlankTitleCdRecs TABLE (EmployeeID varchar(10), [EMP_RCD] smallint, TitleCd varchar(4), POSITION_NBR varchar(10), EFFDT datetime2(7), EFFSEQ smallint)

	TRUNCATE TABLE BlankTitleCdRecs
	INSERT INTO BlankTitleCdRecs
	SELECT DISTINCT 
		   [EmployeeID]
		  ,[EMP_RCD]
		  ,[TitleCd]
		  ,[Position_Nbr]
		  ,[EFFDT]
		  ,[EFFSEQ]
	  FROM [dbo].[' + @TableName + ']
	 

	--DECLARE EmployeeKeyFields TABLE (EMPLID nvarchar(11), EMPL_RCD numeric(38,0), EFFDT datetime2(7), POSITION_NBR nvarchar(8), EFFSEQ smallint, JOBCODE nvarchar(6), DML_IND char(1))
	
	TRUNCATE TABLE EmployeeKeyFields
	INSERT INTO EmployeeKeyFields (EMPLID, EMPL_RCD, EFFDT, POSITION_NBR, EFFSEQ, JOBCODE, DML_IND)
	SELECT EMPLID, EMPL_RCD, EFFDT, POSITION_NBR, EFFSEQ, JOBCODE, DML_IND
	FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
		SELECT DISTINCT EMPLID, EMPL_RCD, EFFDT, EFFSEQ, POSITION_NBR, JOBCODE, DML_IND
		FROM CAESAPP_HCMODS.PS_JOB_V t1
		WHERE JOBCODE <> ''''CONV'''' 
			AND EFFSEQ = (
				SELECT MAX(EFFSEQ)
				 FROM CAESAPP_HCMODS.PS_JOB_V t2
				 WHERE t1.EMPLID = t2.EMPLID AND
					 t1.EMPL_RCD = t2.EMPL_RCD AND
					 t1.EFFDT = t2.EFFDT 
					-- AND t2.DML_IND <> ''''D''''  -- We''''re going to include any deleted records as this is
													--	  how it''''s handled in the UCP-339 report.
			) AND
		EFFDT <= TO_DATE(''''' + CONVERT(char(4), @FiscalYear) + '-09-30'''', ''''yyyy-mm-dd'''') AND
		t1.JOBCODE NOT LIKE '''' %''''
	'') t1
	ORDER BY EMPLID, EMPL_RCD, EFFDT DESC, EFFSEQ DESC, POSITION_NBR, JOBCODE, DML_IND DESC

	-- Try using only EmployeeID, EMP_RCD, and EFFDT fields to find match:

	UPDATE BlankTitleCdRecs
	SET TitleCd = RIGHT(t2.JOBCODE,4)
	FROM BlankTitleCdRecs t1
	INNER JOIN (
		SELECT DISTINCT EmployeeID, EMP_RCD,  t1.EFFDT, t1.EFFSEQ,
			t2.JOBCODE
		FROM BlankTitleCdRecs t1 
		INNER JOIN EmployeeKeyFields t2 ON 
			(
				t1.EmployeeID = t2.EMPLID AND 
				t1.EMP_RCD = t2.EMPL_RCD AND
				t2.EFFDT <= t1.EFFDT 
			) 
		-- 2021-08-02 by kjt: Removed for efficiency.  Assume all title codes are null
		--WHERE t1.titleCd IS NULL AND t2.JOBCODE NOT LIKE '' %''
	) t2 ON 
		t1.EmployeeID = t2.EmployeeID AND 
		t1.EMP_RCD = t2.EMP_RCD AND 
		t1.EFFDT = t2.EFFDT AND 
		t1.EFFSEQ = t2.EFFSEQ
	-- 2021-08-02 by kjt: Removed for efficiency.  Assume all title codes are null
	--WHERE t1.titleCd IS NULL AND t2.JOBCODE NOT LIKE '' %''

	-- I ran into 457 records that still didn''t have a match
	-- ;therefore, I added this portion that matched the remaining
	--	records using emp ID emp_rcd, and position_nbr:

	UPDATE BlankTitleCdRecs
	SET TitleCd = RIGHT(t2.JOBCODE,4)
	FROM BlankTitleCdRecs t1
	INNER JOIN (
		SELECT DISTINCT EmployeeID, EMP_RCD,  t1.EFFDT, t1.EFFSEQ,
			t1.Position_Nbr, t2.JOBCODE 
		FROM  BlankTitleCdRecs t1 
		INNER JOIN EmployeeKeyFields t2 ON 
			(
				t1.EmployeeID = t2.EMPLID AND 
				t1.EMP_RCD = t2.EMPL_RCD AND
				t2.POSITION_NBR = t1.Position_Nbr
			) 
		WHERE t1.titleCd IS NULL -- We still need this check because we just set the majority 
								 --	of the title codes in the first pass.
		-- 2021-08-02 by kjt: We checked for this condition when we loaded the source table.
		--AND t2.JOBCODE NOT LIKE '' %''
	) t2 ON 
		t1.EmployeeID = t2.EmployeeID AND 
		t1.EMP_RCD = t2.EMP_RCD AND 
		t1.EFFDT = t2.EFFDT AND 
		t1.EFFSEQ = t2.EFFSEQ
	WHERE t1.titleCd IS NULL -- We still need this check because we just set the majority 
							 --	of the title codes in the first pass.
	-- 2021-08-02 by kjt: We checked for this condition when we loaded the source table.
	--AND t2.JOBCODE NOT LIKE '' %''
'
	IF @IsDebug = 1
		SELECT @TSQL += '
	--This should return zero (0), all title codes should now have been found:
	SELECT COUNT(*) NumNonNatchedTitleCodesRemaining
	FROM BlankTitleCdRecs
	WHERE TitleCd IS NULL 
'
	SELECT @TSQL += '
	DECLARE @NullTitleCdCount int = (
		SELECT COUNT(*) NumNonNatchedTitleCodesRemaining
		FROM BlankTitleCdRecs
		WHERE TitleCd IS NULL
	)

	IF @NullTitleCdCount != 0
	BEGIN
	--	Try only using just the EMPLID and EMP_RCD for any remaining non-matched titleCds:

		DECLARE @FiscalYear char(4) = ''' + CONVERT(char(4), @FiscalYear)+ ''' 
		DECLARE @EmployeeID varchar(8) = ''''
		DECLARE @EMP_RCD  varchar(2) = ''''
		DECLARE @Position_Nbr varchar(9) = ''''
		DECLARE @EffDt varchar(10) = ''''
		DECLARE @EffSeq varchar(2) = ''''
		DECLARE @TSQL2 varchar(MAX) = ''''
		DECLARE @IsDebug bit = 0


		DECLARE myCursor CURSOR FOR 
		SELECT EmployeeID, EMP_RCD, EFFDT, EFFSEQ, POSITION_NBR 
		FROM BlankTitleCdRecs t1
		WHERE  t1.titleCd IS NULL

		OPEN MyCursor
		FETCH NEXT FROM myCursor INTO @EmployeeID, @EMP_RCD, @EffDt, @EffSeq, @Position_Nbr
		WHILE @@FETCH_STATUS <> -1
		BEGIN
		SELECT @TSQL2 = ''
		UPDATE BlankTitleCdRecs
		SET TitleCd = RIGHT(t2.JOBCODE,4)
		FROM BlankTitleCdRecs t1
		INNER JOIN (
			SELECT DISTINCT EmployeeID, EMPL_RCD AS EMP_RCD, t2.JOBCODE, t1.EFFDT, t1.EFFSEQ
			FROM BlankTitleCdRecs t1 
			INNER JOIN (
				SELECT  EMPLID, EMPL_RCD, JOBCODE, '''''' + @EffDt + '''''' EFFDT, '' + @EffSeq + '' EFFSEQ
				FROM  [dbo].[EmployeeKeyFields] t2
				WHERE
						t2.EMPLID = ''''''+ @EmployeeID + ''''''  AND 
						t2.EMPL_RCD = '' + @EMP_RCD + '' AND
						t2.EFFDT <= '''''' + @FiscalYear + ''-09-30'''' AND
						ABS (DATEDIFF(day, '''''' + @EffDt + '''''', t2.EFFDT)) = 
								(
									SELECT MIN(ABS(DATEDIFF(day, '''''' + @EffDt + '''''', t3.EFFDT)))
									FROM [dbo].[EmployeeKeyFields] t3
									WHERE t2.EMPLID = t3.EMPLID AND
											t2.EMPL_RCD = t3.EMPL_RCD 
							
								) 
				) t2 ON 
				(
					t1.EmployeeID = t2.EMPLID AND 
					t1.EMP_RCD = t2.EMPL_RCD AND
					t1.EFFDT = t2.EFFDT 
				)
			WHERE t1.titleCd IS NULL AND t2.JOBCODE NOT LIKE '''' %''''
		) t2 ON t1.EmployeeID = t2.EmployeeID AND 
			t1.EMP_RCD = t2.EMP_RCD AND
			t1.EFFDT = t2.EFFDT 
		WHERE t1.titleCd IS NULL AND t2.JOBCODE NOT LIKE '''' %''''
	''
		
		IF @IsDebug = 1
			PRINT @TSQL2
		ELSE
			EXEC (@TSQL2)

		FETCH NEXT FROM myCursor INTO @EmployeeID, @EMP_RCD, @EffDt, @EffSeq, @Position_Nbr
	END

	CLOSE myCursor
	DEALLOCATE myCursor
	
	END

'
	IF @IsDebug = 1 
		SELECT @TSQL += '
	--This should return zero (0), all title codes should now have been found:
	SELECT COUNT(*) NumNonNatchedTitleCodesRemaining
	FROM BlankTitleCdRecs
	WHERE TitleCd IS NULL 
'
	SELECT @TSQL += '
	-- Try checking again: 

	SELECT @NullTitleCdCount = (
		SELECT COUNT(*) NumNonNatchedTitleCodesRemaining
		FROM BlankTitleCdRecs
		WHERE TitleCd IS NULL
	)

	-- Last step is to update the AnotherLaborTransactions table
	-- with the title codes we just matched: 

		UPDATE ' + @TableName + '
		SET TitleCd = t2.TitleCd
		FROM ' +  @TableName + ' t1
		INNER JOIN (
			SELECT DISTINCT t1.EmployeeID, t1.EMP_RCD, t1.EFFDT, t1.EFFSEQ, t2.TitleCd
			FROM ' + @TableName + ' t1 
			INNER JOIN BlankTitleCdRecs t2 ON 
				(
					t1.EmployeeID = t2.EmployeeID AND 
					t1.EMP_RCD = t2.EMP_RCD AND
					t1.EFFDT = t2.EFFDT AND 
					t1.EFFSEQ = t2.EFFSEQ
				) 
			-- 2021-08-02 by kjt: Removed for efficiency.  Assume all title codes are null
			-- WHERE t1.titleCd IS NULL AND t2.titleCd IS NOT NULL
			WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
		) t2 ON 
			t1.EmployeeID = t2.EmployeeID AND 
			t1.EMP_RCD = t2.EMP_RCD AND 
			t1.EFFDT = t2.EFFDT AND 
			t1.EFFSEQ = t2.EFFSEQ
		-- 2021-08-02 by kjt: Removed for efficiency.  Assume all title codes are null
		-- WHERE t1.titleCd IS NULL AND t2.TitleCd IS NOT NULL
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
'
	IF @IsDebug = 1
		SELECT @TSQL +='
	SELECT @NullTitleCdCount AS NullTitleCodeCount
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		BEGIN
			EXEC (@TSQL)
			-- We only need to populate the output variable
			-- using SP_ExecuteSQL, since all we need to do is query the
			-- BlankTitleCdRecs table for the result.

			DECLARE @Statement nvarchar(MAX) = '
	SELECT @NullTitleCdCount = (
		SELECT COUNT(*) NumNonNatchedTitleCodesRemaining
		FROM BlankTitleCdRecs
		WHERE TitleCd IS NULL
	)
'
			DECLARE @Params nvarchar(100) = N'@NullTitleCdCount int OUTPUT'
			EXEC sp_executesql @Statement, @Params, @NullTitleCdCount = @NumNullRecs OUTPUT
		END
END