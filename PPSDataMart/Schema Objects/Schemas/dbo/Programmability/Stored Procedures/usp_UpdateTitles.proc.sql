



--==========================================================================
-- Author: Ken Taylor
-- Created On: February 25, 2021
-- Description: Merge the PPSDataMart Titles table using data present in the Titles_PPS table,
--		TitleGroups, and various UCPath HCMODS tables via OPENQUERY. 
-- Prerequsites: The PPSDataMart Titles_PPS and TitleGroups tables must have already been loaded.
-- Usage:
/*
	USE [PPSDataMart]
	GO

	EXEC [dbo].[usp_UpdateTitles] @IsDebug = 0
	GO

*/
-- Modifications:
--	2021-05-11 by kjt: Revised JOBCODE matching logic as duplicate jobcodes existed, some with leading
--		zeros, some without.
--	2021-05-13 by kjt: Fixed issue with WHERE clause.
--	2021-08-03 by kjt: Added additional filter on CR_BT_DTM for join to CAESAPP_HCMODS.PS_UC_JOB_CODES_V
--		as I was getting duplicates on 4220.
--
--==========================================================================
CREATE Procedure [dbo].[usp_UpdateTitles]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS
--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.


	print '-- Downloading Title records...'
	print '-- Selecting most current records from CAESAPP_HCMODS.PS_JOBCODE_TBL_V'
	print '-- IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True (Just display SQL. Don''t update anything)' ELSE 'False (Run script)' END
	print '-------------------------------------------------------------------------'
	
select @TSQL = '
MERGE PPSDataMart.dbo.Titles Titles
	USING
	(
	SELECT  DISTINCT
      t1.JOBCODE TitleCode
	  ,COALESCE(t8.Name, t1.DESCR) Name
	  ,t1.DESCR AbbreviatedName
	  ,COALESCE(CASE 
		WHEN t1.JOBCODE BETWEEN ''4000'' AND ''4008'' OR t1.JOBCODE BETWEEN ''4010'' AND ''4384'' OR t1.JOBCODE BETWEEN ''4386'' AND ''5670'' OR 
			t1.JOBCODE BETWEEN ''5672'' AND ''5677'' OR t1.JOBCODE BETWEEN ''5811'' AND ''5875'' OR t1.JOBCODE BETWEEN ''6099'' AND ''6466'' OR 
			t1.JOBCODE BETWEEN ''6650'' AND ''6776'' OR t1.JOBCODE BETWEEN ''6900'' AND ''9999'' 
		THEN ''1''
		WHEN t1.JOBCODE BETWEEN ''0001'' AND ''0799'' OR t1.JOBCODE  IN (''4009'', ''4385'') OR  t1.JOBCODE  BETWEEN ''5680'' AND ''5810'' OR 
			t1.JOBCODE  BETWEEN ''5876'' AND ''6098'' OR t1.JOBCODE  BETWEEN ''6467'' AND ''6649'' OR t1.JOBCODE  BETWEEN ''6777'' AND ''6899''
		THEN ''2''
		WHEN t1.JOBCODE BETWEEN ''0800'' AND ''3999''
		THEN ''A''
	END, t3.PersonnelProgramCode) PersonnelProgramCode
	  ,CASE WHEN UNION_CD LIKE ''%[%]'' THEN LEFT(UNION_CD,1) + ''3'' ELSE UNION_CD  END UnitCode
	  ,t2.TitleGroup, t9.Description TitleGroupDescription,FLSA_STATUS OvertimeExemptionCode, t3.CTOOccupationSubgroupCode
	  ,t8.FederalOccupationCode, t8.FOCSubcategoryCode, t8.LinkTitleGroupCode,t1.JOB_FAMILY,t5.DESCR JOB_FAMILY_DESC
	  ,EEO1CODE AS EE06CategoryCode,t8.StaffType,t1.JOB_FUNCTION,t4.DESCR JOB_FUNCTION_DESCR
	  ,t1.US_OCC_CD
	  ,t6.DESCR50 US_OCC_CD_DESC
	  ,t1.US_SOC_CD
	  ,t7.DESCR50 US_SOC_CD_DESC
	  ,t2.ESTABID
      ,CASE WHEN t1.EFFDT < t8.EffectiveDate THEN t8.EffectiveDate ELSE t1.EFFDT END EffectiveDate
      ,CASE WHEN t1.LASTUPDDTTM < t8.UpdateTimestamp THEN UpdateTimestamp ELSE t1.LASTUPDDTTM END UpdateTimestamp
	  ,CASE WHEN t8.TitleCode IS NULL THEN 1 ELSE 0 END IsNewInUCP
  FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
	SELECT 
		SETID,SUBSTR(JOBCODE,3,4) JOBCODE,EFFDT,EFF_STATUS,DESCR,DESCRSHORT,JOB_FUNCTION,SETID_SALARY,
		SAL_ADMIN_PLAN,GRADE,STEP,MANAGER_LEVEL,SURVEY_SALARY,SURVEY_JOB_CODE,UNION_CD,RETRO_RATE,
		RETRO_PERCENT,CURRENCY_CD,STD_HOURS,STD_HRS_FREQUENCY,COMP_FREQUENCY,WORKERS_COMP_CD,JOB_FAMILY,
		REG_TEMP,DIRECTLY_TIPPED,MED_CHKUP_REQ,FLSA_STATUS,EEO1CODE,EEO4CODE,EEO5CODE,EEO6CODE,EEO_JOB_GROUP,
		US_SOC_CD,IPEDSSCODE,US_OCC_CD,AVAIL_TELEWORK,FUNCTION_CD,TRN_PROGRAM,COMPANY,BARG_UNIT,ENCUMBER_INDC,
		POSN_MGMT_INDC,EG_ACADEMIC_RANK,EG_GROUP,ENCUMB_SAL_OPTN,ENCUMB_SAL_AMT,LAST_UPDATE_DATE,REG_REGION,
		SAL_RANGE_MIN_RATE,SAL_RANGE_MID_RATE,SAL_RANGE_MAX_RATE,SAL_RANGE_CURRENCY,SAL_RANGE_FREQ,JOB_SUB_FUNC,
		LASTUPDOPRID,LASTUPDDTTM,KEY_JOBCODE,CR_BT_DTM,CR_BT_NBR,UPD_BT_DTM,UPD_BT_NBR,ODS_VRSN_NBR,DML_IND  
	FROM CAESAPP_HCMODS.PS_JOBCODE_TBL_V t1
	WHERE t1.SETID = ''''UCSHR'''' AND 
		t1.EFF_STATUS = ''''A'''' AND
	  t1.EFFDT = (
		SELECT MAX(EFFDT)
		FROM CAESAPP_HCMODS.PS_JOBCODE_TBL_V J2
		WHERE t1.SETID = J2.SETID AND
			CASE WHEN SUBSTR(t1.JOBCODE,1,2) LIKE ''''00'''' THEN SUBSTR(t1.JOBCODE,3, 4)
				 WHEN LENGTH(t1.JOBCODE) = 4 THEN t1.JOBCODE
				 ELSE t1.JOBCODE 
			END =  
			CASE WHEN SUBSTR(J2.JOBCODE,1,2) LIKE ''''00'''' THEN SUBSTR(J2.JOBCODE,3, 4)
				 WHEN LENGTH(J2.JOBCODE) = 4 THEN J2.JOBCODE
				 ELSE J2.JOBCODE END AND
			t1.EFF_STATUS = J2.EFF_STATUS AND 
			J2.DML_IND <> ''''D'''' AND
			J2.EFFDT <= CURRENT_DATE
	)
'') t1
LEFT OUTER JOIN 
( 
  SELECT ESTABID
      ,UC_JOB_GROUP TitleGroup --Or FederalOccupationCode
      ,JOBCODE
  FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
  SELECT * 
  FROM CAESAPP_HCMODS.PS_UC_JOB_CODE_TBL_V t1
  WHERE 
	  ESTABID = ''''UCD'''' AND 
	  EFFDT = 
	  (
		SELECT MAX(EFFDT) 
		FROM CAESAPP_HCMODS.PS_UC_JOB_CODE_TBL_V t2
		WHERE t1.JOBCODE = t2.JOBCODE AND
		t1.ESTABID = t2.ESTABID AND
		t2.DML_IND <> ''''D'''' AND
		t2.EFFDT <= CURRENT_DATE
	  )
  '')
) t2 ON t1.JOBCODE = RIGHT(t2.JOBCODE,4)
LEFT OUTER JOIN (
	SELECT 
		   JOBCODE
		  ,UC_CTO_OS_CD CTOOccupationSubgroupCode
		  ,CLASS_INDC PersonnelProgramCode
	  FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
	  SELECT *  
	  FROM CAESAPP_HCMODS.PS_UC_JOB_CODES_V ucj
	  WHERE SETID = ''''UCSHR'''' AND 
	  EFFDT = (
		SELECT MAX(EFFDT) 
		FROM  CAESAPP_HCMODS.PS_UC_JOB_CODES_V ucj2
		WHERE ucj.JOBCODE = ucj2.JOBCODE AND
		ucj.SETID = ucj2.SETID AND 
		ucj.JOBCODE = ucj2.JOBCODE AND
		ucj2.DML_IND <> ''''D'''' AND
		ucj2.EFFDT <= CURRENT_DATE
	  )  AND
	  -- Added because I was getting duplicatess for 4220
	  CR_BT_DTM = (
		SELECT MAX(CR_BT_DTM)
		FROM CAESAPP_HCMODS.PS_UC_JOB_CODES_V ucj3
		WHERE ucj.JOBCODE = ucj3.JOBCODE AND
		ucj.SETID = ucj3.SETID AND 
		ucj.JOBCODE = ucj3.JOBCODE AND
		ucj3.DML_IND <> ''''D'''' AND
		ucj3.EFFDT <= CURRENT_DATE
	  )
   '')
  ) t3 ON t1.JOBCODE = RIGHT(t3.JOBCODE,4)
  LEFT OUTER JOIN (
	  SELECT JOB_FUNCTION
		  ,DESCR
		  ,INAIL_CODE
	  FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
		SELECT *
		FROM CAESAPP_HCMODS.PS_JOBFUNCTION_TBL_V t1
	  WHERE 
	  EFFDT = 
	  (
		SELECT MAX(EFFDT) 
		FROM  CAESAPP_HCMODS.PS_JOBFUNCTION_TBL_V t2
		WHERE t1.JOB_FUNCTION = t2.JOB_FUNCTION AND
		t2.DML_IND <> ''''D'''' AND
		t2.EFFDT <= CURRENT_DATE
	  )
   '')
  ) t4 ON t1.JOB_FUNCTION = t4.JOB_FUNCTION
  LEFT OUTER JOIN (
	SELECT *
	FROM OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)], ''
		SELECT * 
		FROM CAES_HCMODS.PS_JOB_FAMILY_TBL_V t1
		WHERE EFFDT = (
			SELECT MAX(EFFDT)
			FROM CAES_HCMODS.PS_JOB_FAMILY_TBL_V t2
			WHERE t1.JOB_FAMILY = t2.JOB_FAMILY AND
				t1.EFF_STATUS = t2.EFF_STATUS AND
				t2.DML_IND <> ''''D'''' AND
				t2.EFFDT <= CURRENT_DATE
		) AND EFF_STATUS = ''''A''''
  '')
  ) t5 ON t1.JOB_FAMILY = t5.JOB_FAMILY
  LEFT OUTER JOIN (
	SELECT * FROM OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],''
	SELECT * FROM CAES_HCMODS.PS_US_OCC_TBL_V t1
	WHERE EFFDT = (
		SELECT MAX(EFFDT) FROM CAES_HCMODS.PS_US_OCC_TBL_V t2
		WHERE t1.US_OCC_CD = t2.US_OCC_CD AND
			t1.EFF_STATUS = t2.EFF_STATUS AND
			t2.DML_IND <> ''''D'''' AND
			t2.EFFDT <= CURRENT_DATE
	) AND EFF_STATUS = ''''A''''
  '')
  ) t6 ON t1.US_OCC_CD = t6.US_OCC_CD
   LEFT OUTER JOIN (
		SELECT * FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)] ,''
	SELECT * FROM CAESAPP_HCMODS.PS_US_SOC_TBL_V t1
	WHERE EFFDT = (
		SELECT MAX(EFFDT) FROM CAESAPP_HCMODS.PS_US_SOC_TBL_V t2
		WHERE t1.US_SOC_CD = t2.US_SOC_CD AND
			t1.EFF_STATUS = t2.EFF_STATUS AND
			t2.DML_IND <> ''''D'''' AND
			t2.EFFDT <= CURRENT_DATE
	) AND EFF_STATUS = ''''A''''
  '')
  ) t7 ON t1.US_SOC_CD = t7.US_SOC_CD
  LEFT OUTER JOIN PPSDataMart.dbo.Titles_PPS t8 ON t1.JOBCODE = t8.TitleCode  
	AND EffectiveDate = (
		SELECT MAX(EffectiveDate) 
		FROM PPSDataMart.dbo.Titles_PPS t8b
		WHERE 
			t8.TitleCode = t8b.TitleCode AND 
			t8b.EffectiveDate <= GETDATE()
	 )
  LEFT OUTER JOIN PPSDataMart.dbo.TitleGroups t9 ON t2.TitleGroup = t9.JobGroupID
  WHERE t1.JOBCODE != ''CONV''
  
) t1 on Titles.TitleCode = t1.TitleCode

	WHEN MATCHED THEN UPDATE set
	   Name = t1.Name,AbbreviatedName = t1.AbbreviatedName,PersonnelProgramCode = t1.PersonnelProgramCode
      ,UnitCode = t1.UnitCode,TitleGroup = t1.TitleGroup,TitleGroupDescription = t1.TitleGroupDescription
      ,OvertimeExemptionCode = t1.OvertimeExemptionCode,FederalOccupationCode = t1.FederalOccupationCode
      ,FOCSubcategoryCode = t1.FOCSubcategoryCode,LinkTitleGroupCode = t1.LinkTitleGroupCode,JobFamily = JOB_FAMILY
      ,JobFamilyDescription = JOB_FAMILY_DESC,EE06CategoryCode = t1.EE06CategoryCode,JobFunction = JOB_FUNCTION
	  ,JobFunctionDescription = JOB_FUNCTION_DESCR,UsOccCode = US_OCC_CD,UsOccCodeDescription = US_OCC_CD_DESC
	  ,UsSocCode = US_SOC_CD,UsSocCodeDescription = US_SOC_CD_DESC,EstabID = t1.ESTABID
	  ,EffectiveDate = t1.EffectiveDate,UpdateTimestamp = t1.UpdateTimestamp
    WHEN NOT MATCHED BY TARGET THEN INSERT VALUES (
	   TitleCode,Name,AbbreviatedName,PersonnelProgramCode,UnitCode,TitleGroup,TitleGroupDescription
      ,OvertimeExemptionCode,CTOOccupationSubgroupCode,FederalOccupationCode,FOCSubcategoryCode
      ,LinkTitleGroupCode,JOB_FAMILY,JOB_FAMILY_DESC,EE06CategoryCode,StaffType,JOB_FUNCTION,JOB_FUNCTION_DESCR
      ,US_OCC_CD ,US_OCC_CD_DESC,US_SOC_CD,US_SOC_CD_DESC,ESTABID,EffectiveDate,UpdateTimestamp,IsNewInUCP
    );'
	
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
