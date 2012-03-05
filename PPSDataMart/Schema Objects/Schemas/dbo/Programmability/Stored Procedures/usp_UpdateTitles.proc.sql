CREATE Procedure [dbo].[usp_UpdateTitles]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS
--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.


	print '-- Downloading Title records...'
	print '-- Selecting all records from PAYROLL.CTLTCI'
	print '-- IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True (Just display SQL. Don''t update anything)' ELSE 'False (Run script)' END
	print '-------------------------------------------------------------------------'
	
select @TSQL = 
	'merge PPSDataMart.dbo.Titles Titles
	using
	(
	SELECT 
		TCI_TITLE_CODE, 
		TCI_TITLE_NAME, 
		TCI_TITLE_NM_ABBRV, 
		TCI_PERSONL_PGM_CD, 
		TCI_TITLE_UNIT_CD,
		JGT_JOB_GROUP_ID, 
		TCI_OVRTM_EXMPT_CD,
		TCI_CTO_OSC,
		TCI_FOC,
		TCI_FOC_SUBCAT_CD,
		TCI_LINKG_CD_TITLE,
		JGT_EE06_CATEGORY,
		TCI_EFFECTIVE_DATE, 
		CAST(TCI_UPDT_TIMESTAMP as datetime) as UPDT_TIMESTAMP
	FROM OPENQUERY(PAY_PERS_EXTR, ''
		SELECT 
			TCI_TITLE_CODE, 
			TCI_TITLE_NAME, 
			TCI_TITLE_NM_ABBRV, 
			TCI_PERSONL_PGM_CD, 
			TCI_TITLE_UNIT_CD,
			JGT_JOB_GROUP_ID, 
			TCI_OVRTM_EXMPT_CD, 
			TCI_CTO_OSC,
			TCI_FOC,
			TCI_FOC_SUBCAT_CD,
			TCI_LINKG_CD_TITLE,
			JGT_EE06_CATEGORY,
			TCI_EFFECTIVE_DATE, 
			SUBSTR(tci_updt_timestamp, 0, 10) TCI_UPDT_TIMESTAMP 
		FROM PAYROLL.CTLTCI 
	LEFT OUTER JOIN PAYROLL.CTLJGT ON PAYROLL.CTLTCI.TCI_TITLE_CODE = PAYROLL.CTLJGT.JGT_TITLE_CODE
'')
) CTLTCI on Titles.TitleCode = CTLTCI.TCI_TITLE_CODE

	WHEN MATCHED THEN UPDATE set
	   [Name] = TCI_TITLE_NAME
      ,[AbbreviatedName] = TCI_TITLE_NM_ABBRV
      ,[PersonnelProgramCode] = TCI_PERSONL_PGM_CD
      ,[UnitCode] = TCI_TITLE_UNIT_CD
      ,[TitleGroup] = JGT_JOB_GROUP_ID
      ,[OvertimeExemptionCode] = TCI_OVRTM_EXMPT_CD
      ,[CTOOccupationSubgroupCode] = TCI_CTO_OSC
      ,[FederalOccupationCode] = TCI_FOC
      ,[FOCSubcategoryCode] = TCI_FOC_SUBCAT_CD
      ,[LinkTitleGroupCode] = TCI_LINKG_CD_TITLE
      ,[EE06CategoryCode] = JGT_EE06_CATEGORY
      ,[EffectiveDate] = TCI_EFFECTIVE_DATE
      ,[UpdateTimestamp] = UPDT_TIMESTAMP
      
    WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      (
		TCI_TITLE_CODE, 
		TCI_TITLE_NAME, 
		TCI_TITLE_NM_ABBRV, 
		TCI_PERSONL_PGM_CD, 
		TCI_TITLE_UNIT_CD,
		JGT_JOB_GROUP_ID, 
		TCI_OVRTM_EXMPT_CD,
		TCI_CTO_OSC,
		TCI_FOC,
		TCI_FOC_SUBCAT_CD,
		TCI_LINKG_CD_TITLE,
		JGT_EE06_CATEGORY,
		NULL,
		TCI_EFFECTIVE_DATE, 
		UPDT_TIMESTAMP
      )
--	WHEN NOT MATCHED BY SOURCE THEN DELETE
	;'
	
	-------------------------------------------------------------------------
	
	if @IsDebug = 1
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END
		
	 print '-------------------------------------------------------------------------'
