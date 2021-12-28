

-- =============================================
-- Author:		Ken Taylor
-- Create date: October 9, 2020
-- Description:	Performs the various updates on AnotherLaborTransactions table
--		after table has been initially loaded.
-- Note: This logic was split out from usp_LoadAnotherLaborTransactions to
--		simplify the logic.
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE @NullDosCodeCount int, @BlankTitleCodeCount int, @IsDebug bit = 1

SET NOCOUNT ON;
EXEC	[dbo].[usp_UpdateAnotherLaborTransactions]
		@FiscalYear = 2021,
		@IsDebug = @IsDebug,
		@TableName = 'AnotherLaborTransactions_Temp', 
		@NumNullDosCodes = @NullDosCodeCount OUTPUT,
		@NumNullRecs = @BlankTitleCodeCount OUTPUT

IF @IsDebug = 0
	SELECT	 'NullDosCodeCount' = @NullDosCodeCount, 'BlankTitleCodeCount' = @BlankTitleCodeCount

SET NOCOUNT OFF;

GO

*/
-- Modifications
--	2021-07-30 by kjt: Various modifications mainly pertaining to index manipulation,
--		and setting of ReportingYear filter in where clause, as this is part of the PK.
--	2021-08-02 by kjt: Added logic for disabling All indexes less PK and then re-enabling
--		index on EmployeeID only prior to setting EmployeeName as this appears to be the
--		most efficient technique.
--	2021-08-25 by kjt: Revised to include 2 output parameters, plus have correct usage sample.
--	2021-08-27 by kjt: Revised to return the number of DISTINCT DOS Codes that were un-identified as
--		opposed to the total number of records with NULL DOS codes.
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateAnotherLaborTransactions] 
	@FiscalYear int = 2020, 
	@IsDebug bit = 0,
	@TableName varchar(50) = 'AnotherLaborTransactions_Temp', -- This is the name of the temp, i.e. staging, table
															  --	we're using.
	@NumNullDosCodes int OUTPUT,
	@NumNullRecs int OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET ANSI_NULLS ON

	SET QUOTED_IDENTIFIER ON

	DECLARE @TSQL varchar(MAX) = ''

	DECLARE @QueryParameterTable AS QueryParameterTableType;
	INSERT INTO @QueryParameterTable
	SELECT ARCCode FROM ARCCodes

	DECLARE @ARCCodesString varchar(MAX) =  (
		SELECT dbo.udf_CommaDelimitedStringFromTableType(@QueryParameterTable, 1)
	)

-- Misc. housekeeping:
	 SELECT @TSQL = '
	  UPDATE [dbo].[' + @TableName + ']
	  SET ORG = OrgID
	  WHERE Org = ''-ANR'' AND Chart = ''L'' AND ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '

	 UPDATE [dbo].[' + @TableName + ']
	 SET 
		School = t2.ORG_ID_LEVEL_4, 
		ExcludedByOrg = CASE WHEN t2.ORG_ID_LEVEL_4 IN (''AAES'', ''BIOS'') THEN 0 ELSE 1 END 
	 FROM [dbo].[' + @TableName + '] t1
	 INNER JOIN 
	  (
		SELECT CHART_NUM, ORG_ID, ORG_ID_LEVEL_4
		FROM OPENQUERY([FIS_DS], ''
			SELECT O.CHART_NUM, O.ORG_ID, O.ORG_ID_LEVEL_4
			FROM FINANCE.ORGANIZATION_HIERARCHY O
		
			WHERE O.FISCAL_YEAR = 9999 AND 
				O.FISCAL_PERIOD = ''''--''''
		'')
	   ) t2 ON t1.Chart = t2.CHART_NUM AND
			ORG		= t2.ORG_ID
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '--t1.School IS NULL --Faster if we omit this filter, and assume all records need to be updated.
	  '
   	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	-- Set the IsAES flag:
	SELECT @TSQL = '
	UPDATE [dbo].[' + @TableName + ']
	SET [IsAES] = 
		CASE WHEN AnnualReportCode IN (' + @ARCCodesString +')
			THEN 1 
			ELSE 0
		END
	WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' --[IsAES] IS NULL --Faster if we omit this filter, and assume all records need to be updated.
	'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	SELECT @TSQL = '
	UPDATE [dbo].[' + @TableName + ']
	SET ExcludedByDOS = t2.ExcludedByDOS
	FROM [dbo].[' + @TableName + '] t1
	INNER JOIN (
		SELECT DISTINCT t1.DosCd, t2.IncludeInAD419FTE, 
		CASE t2.IncludeInAD419FTE WHEN 1 THEN 0 WHEN 0 THEN 1 ELSE NULL END AS ExcludedByDOS
		FROM [dbo].[' + @TableName + '] t1
		LEFT OUTER JOIN dbo.DOS_Codes t2
			ON t1.DosCd = t2.DOS_Code 
		WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' --t1.ExcludedByDOS IS NULL --Faster if we omit this filter, and assume all records need to be updated.
	) t2 ON t1.DosCd = t2.DosCd
	WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' --t1.ExcludedByDOS IS NULL --Faster if we omit this filter, and assume all records need to be updated.
'
		IF @IsDebug = 1  
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)

	SELECT @TSQL = '
	UPDATE  [dbo].[' + @TableName + '] 
	SET ExcludedByAccount = CASE WHEN t2.Account IS NULL THEN 0 ELSE 1 END
	FROM [dbo].[' + @TableName + '] t1
	LEFT OUTER JOIN (
		SELECT DISTINCT Chart, Account 
		FROM [dbo].ArcCodeAccountExclusions
		) t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
	WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' --ExcludedByAccount IS NULL --Faster if we omit this filter, and assume all records need to be updated.
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	SELECT @TSQL = '
	UPDATE  [dbo].[' + @TableName + '] 
	SET ExcludedByObjConsol = CASE WHEN t2.Obj_Consolidatn_Num IS NOT NULL THEN 0 ELSE 1 END
	FROM [dbo].[' + @TableName + ']  t1
	LEFT OUTER JOIN [dbo].ConsolCodesForLaborTransactions t2 ON t1.ObjConsol = t2.Obj_Consolidatn_Num 
	WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' --t1.ExcludedByObjConsol IS NULL --Faster if we omit this filter, and assume all records need to be updated.
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	SELECT @TSQL = '
	UPDATE [dbo].[' + @TableName + ']
			SET PPS_ID = t2.EmployeeId
	FROM [dbo].[' + @TableName + '] t1
	INNER JOIN (
		SELECT  [EMPLID]
			,[BUSINESS_UNIT]
			,[UC_EXT_SYSTEM_ID] EmployeeId
			,[EFFDT]
			,[EFF_STATUS]
			,[UC_EXT_SYSTEM_ID]
     
		FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
		SELECT * FROM CAESAPP_HCMODS.PS_UC_EXT_SYSTEM_V t1
		WHERE UC_EXT_SYSTEM = ''''PPS_ID'''' AND EFFDT =
		(
			SELECT MAX(EFFDT) FROM CAESAPP_HCMODS.PS_UC_EXT_SYSTEM_V  t2
			WHERE t1.BUSINESS_UNIT = t2.BUSINESS_UNIT AND
				t1.UC_EXT_SYSTEM = t2.UC_EXT_SYSTEM AND 
				t1.EMPLID = t2.EMPLID AND
				t2.DML_IND <> ''''D'''' AND
				t2.EFFDT <= CURRENT_DATE
		)
		'')
	) t2 ON t1.EmployeeID = t2.EMPLID
	WHERE ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' --t1.PPS_ID IS NULL  --Faster if we omit this filter, and assume all records need to be updated.
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	  SELECT @TSQL = '
		UPDATE [dbo].[' + @TableName + ']
		SET PPS_ID = t2.PPS_ID
		FROM [dbo].[' + @TableName + '] t1
		INNER JOIN (
			SELECT DISTINCT t1.EmployeeName,  t2.PERSON_NM, t2.EMPLOYEE_Id EmployeeId, t2.PPS_ID
			FROM [dbo].[' + @TableName + '] t1
			LEFT OUTER JOIN [dbo].[RICE_UC_KRIM_PERSON_V] t2
				ON t1.EmployeeId = t2.EMPLOYEE_ID
			WHERE t1.PPS_ID IS NULL AND t2.PPS_ID IS NOT NULL AND ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
		) t2 ON t1.EmployeeId = t2.EmployeeId
		WHERE t1.PPS_ID IS NULL AND t2.PPS_ID IS NOT NULL AND ReportingYear = ' + CONVERT(char(4), @FiscalYear) + '
	'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	  SELECT @TSQL = '
	
	-- For best performance: Disable all indexes except PK and EmployeeId index for best performance, aand do not check for nulls.

	EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName =''' + @TableName + '''
	'

	-- Enable index on EmployeeId:
	SET NOCOUNT ON 
	DECLARE @IndexTable TABLE(index_name varchar(255), index_description varchar(255), index_keys varchar(255))
	INSERT INTO @IndexTable
	exec sp_helpindex @TableName

	DECLARE @IndexName varchar(255) = (
	SELECT index_name FROM @IndexTable
	WHERE index_keys = 'EmployeeId'
	)

	SELECT @TSQL += 'ALTER INDEX [' + @IndexName + '] ON [dbo].[' + @TableName + '] REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	  
	  SELECT @TSQL = '
	  TRUNCATE TABLE [dbo].[EmployeeNames]

	  INSERT INTO [dbo].[EmployeeNames]
		SELECT DISTINCT 
				t2.EMPLID EmployeeId,
				--t2.LAST_NAME,
				--t2.FIRST_NAME,
				--t2.MIDDLE_NAME,
				--t2.NAME_SUFFIX,
				t2.LAST_NAME + '','' + t2.FIRST_NAME + RTRIM('' '' + t2.MIDDLE_NAME) + RTRIM('' '' + t2.NAME_SUFFIX) EmployeeName
		FROM  OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)], ''
				SELECT DISTINCT 
					EMPLID, 
					LAST_NAME,
					FIRST_NAME,
					MIDDLE_NAME,
					NAME_SUFFIX
				FROM CAES_HCMODS.PS_UC_LL_EMPL_DTL_V t2
				WHERE EFFDT = (
					SELECT MAX(EFFDT)
					FROM  CAES_HCMODS.PS_UC_LL_EMPL_DTL_V  t3 
					WHERE
						t2.EMPLID = t3.EMPLID AND T3.DML_IND <> ''''D'''' AND
						t3.EFFDT <= CURRENT_DATE
				) AND 
				EFFSEQ = (	
					SELECT MAX(EFFSEQ)
					FROM CAES_HCMODS.PS_UC_LL_EMPL_DTL_V  t4
					WHERE
						t2.EMPLID = t4.EMPLID AND T4.DML_IND <> ''''D'''' AND
						t2.EFFDT = t4.EFFDT
				) AND

				-- This additional filter prevents duplicate employee names, by only fetching the one on the latest paycheck; otherwise we had duplicates.
				PAY_END_DT = (
					SELECT MAX(PAY_END_DT)
					FROM CAES_HCMODS.PS_UC_LL_EMPL_DTL_V  t5 
					WHERE 
						t2.EMPLID = t5.EMPLID AND 
						t2.EFFDT = t5.EFFDT AND
						t2.EFFSEQ = t5.EFFSEQ AND 
						t5.DML_IND <> ''''D''''
						AND t2.LAST_NAME NOT LIKE '''' %''''
				)  
			'') t2 

	  UPDATE [dbo].[' + @TableName + ']
	  SET EmployeeName = t2.EmployeeName
	  FROM [dbo].[' + @TableName + '] t1
	  INNER JOIN [dbo].[EmployeeNames] t2 ON t1.EmployeeID = t2.EmployeeID AND 
		t1.ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' --t1.EmployeeName IS NULL OR t1.EmployeeName = '''' --Faster if we omit this filter, and assume all records need to be updated.

	  SELECT count(*) Blank_EmployeeNames FROM [dbo].[' + @TableName + ']
	  WHERE EmployeeName = '''' OR EmployeeName IS NULL
	'
		IF @IsDebug = 1  
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)
	--(503729 rows affected)
	--(1 row affected)

	 SELECT @TSQL = '
		DECLARE @BlankTitleCodeCount int

		EXEC usp_UpdateAnotherLaborTransactionsBlankTitleCodes
			@FiscalYear = ' + CONVERT(char(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(char(1), @IsDebug) + ',
			@TableName = ''' + @TableName + ''',
			@NumNullRecs =  @BlankTitleCodeCount OUTPUT
'

		IF @IsDebug = 1 
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)
	--(503729 rows affected)

	  SELECT @TSQL = '
		DECLARE @NullDosCodeCount int = 
		(SELECT Count(DOSCd) [NumberOfDosCodesWithoutClassification:] FROM [dbo].[' + @TableName + ']
		WHERE ExcludedByDOS IS NULL AND 
			CalculatedFTE <> 0 AND 
			ExcludedByOrg = 0 AND 
			ExcludedByARC = 0 AND 
			ExcludedByAccount = 0 AND
			ExcludedByObjConsol = 0)

		IF @NullDosCodeCount = 0 
		BEGIN
		  UPDATE [dbo].[' + @TableName + ']
		  SET IncludeInFTECalc = CASE WHEN 
				ExcludedByARC = 0 AND 
				ExcludedByOrg = 0 AND 
				ExcludedByAccount = 0 AND
				ExcludedByObjConsol = 0 AND
				COALESCE(ExcludedByDOS,1) = 0 THEN 1 ELSE 0 END
			WHERE IncludeInFTECalc IS NULL

			SELECT ''Completed setting IncludeInFTECalc flag'' AS [Message:]
		END 
		ELSE
		BEGIN
			SELECT ''Unable to set IncludeInFTECalc because not all flags are set.'' AS [Message:]

			SELECT Count(DISTINCT DOSCd) [NumberOfDosCodesWithoutClassification:] FROM [dbo].[' + @TableName + ']
			WHERE ExcludedByDOS IS NULL AND 
				CalculatedFTE <> 0 AND 
				ExcludedByOrg = 0 AND 
				ExcludedByARC = 0 AND 
				ExcludedByAccount = 0 AND
				ExcludedByObjConsol = 0
		END
'
	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
	BEGIN
		EXEC(@TSQL)

		DECLARE @Statement nvarchar(MAX) = '
	-- This sets the 2 output values:

	 SELECT @NullDosCodeCount = 
		(SELECT Count(DISTINCT DOSCd) [NumberOfDosCodesWithoutClassification:] FROM [dbo].[' + @TableName + ']
		WHERE ExcludedByDOS IS NULL AND 
			CalculatedFTE <> 0 AND 
			ExcludedByOrg = 0 AND 
			ExcludedByARC = 0 AND 
			ExcludedByAccount = 0 AND
			ExcludedByObjConsol = 0)

	  SELECT @NullTitleCdCount = (
		SELECT COUNT(*) NumNonNatchedTitleCodesRemaining
		FROM BlankTitleCdRecs
		WHERE TitleCd IS NULL
	)
'			-- This last step is necessary if we want to return data to the calling procedure:

			DECLARE @Params nvarchar(100) = N'@NullTitleCdCount int OUTPUT, @NullDosCodeCount int OUTPUT'
			EXEC sp_executesql @Statement, @Params, @NullTitleCdCount = @NumNullRecs OUTPUT, @NullDosCodeCount = @NumNullDosCodes OUTPUT
	END

	SET NOCOUNT ON;

END