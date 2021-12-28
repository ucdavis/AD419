
-- Author: Ken Taylor
-- Modified On: 2021-02-23
-- Purpose: To update the PPS Datamart UCP_PersonJob table with data from UC Path
-- Usage:
/*

	USE [PPSDataMart]
	GO

	EXEC [dbo].[usp_Update_UCPath_PersonJob]
		@IsDebug = 0

	GO

*/

-- Modifications:
--	2021-04-05 by kjt: Modified join to ps_uc_ext_system_v to include BUSINESS_UNIT as data also present
--	for both DVCMP and UCOP1, causing duplicate PPS_Ids to be returned for the same UCP EMPLID.
--	2021-06-23 by kjt: Added "AND _.DML_IND <> 'D' to the OPENQUERY SQL statements to help avoid
--		issues with items with the same effdt, etc, but with differing information that resulted in
--		duplicate records and the load to fail after the table had been truncated resulting in an 
--		empty table.
--	2021-08-03 by kjt: Combined lines and removed some spaces to keep text from being truncated.
--	2021-08-04 by kjt: Revised to use [dbo].[UCPath_PersonJob_Source_V] as openquery source, plus
--		modified to use MERGE for update and insert.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_Update_UCPath_PersonJob]
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET ANSI_NULLS ON

	SET QUOTED_IDENTIFIER ON

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName = ''UCPath_PersonJob''

	MERGE UCPath_PersonJob D
	USING (
		SELECT * FROM UCPath_PersonJob_Source_V --2021-04
	) S ON D.EMP_ID = S.EMP_ID AND D.EMP_RCD = S.EMP_RCD AND D.EFF_DT = S.EFF_DT AND D.EFF_SEQ = S.EFF_SEQ
	WHEN MATCHED THEN UPDATE SET
		NAME=S.NAME,
		LAST_NAME=S.LAST_NAME,
		FIRST_NAME=S.FIRST_NAME,
		MIDDLE_NAME=S.MIDDLE_NAME,
		NAME_PREFIX=S.NAME_PREFIX,
		NAME_SUFFIX=S.NAME_SUFFIX,
		PPS_ID=S.PPS_ID,
		BIRTHDATE=S.BIRTHDATE,
		EMP_HIGH_EDU_LVL_CD=S.EMP_HIGH_EDU_LVL_CD,
		EMP_HIGH_EDU_LVL_DESC=S.EMP_HIGH_EDU_LVL_DESC,
		HIRE_DT=S.HIRE_DT,
		EMP_ORIG_HIRE_DT=S.EMP_ORIG_HIRE_DT,
		EMP_WRK_PH_NUM=S.EMP_WRK_PH_NUM,
		EMP_SPOUSE_FULL_NM=S.EMP_SPOUSE_FULL_NM,
		RPTS_TO_POSN_NBR_COUNT=S.RPTS_TO_POSN_NBR_COUNT,
		JOBCODE=S.JOBCODE,
		JOBCODE_DESC=S.JOBCODE_DESC,
		PER_ORG=S.PER_ORG,
		JOB_FUNCTION=S.JOB_FUNCTION,
		JOB_FUNCTION_DESC=S.JOB_FUNCTION_DESC,
		UNION_CD=S.UNION_CD,
		POSN_NBR=S.POSN_NBR,
		RPTS_TO_POSN_NBR=S.RPTS_TO_POSN_NBR,
		SAL_ADMIN_PLAN=S.SAL_ADMIN_PLAN,
		GRADE=S.GRADE,
		STEP=S.STEP,
		EARNS_DIST_TYPE=S.EARNS_DIST_TYPE,
		STD_HOURS=S.STD_HOURS,
		STD_HRS_FREQUENCY=S.STD_HRS_FREQUENCY,
		FTE=S.FTE,
		JOB_F_FTE_PCT=S.JOB_F_FTE_PCT,
		COMP_FREQUENCY=S.COMP_FREQUENCY,
		COMPRATE=S.COMPRATE,
		ANNL_RATE=S.ANNL_RATE,
		CALC_ANNUAL_RATE=S.CALC_ANNUAL_RATE,
		EMP_STAT=S.EMP_STAT,
		EMPL_STAT_DESC=S.EMPL_STAT_DESC,
		HR_STAT=S.HR_STAT,
		HR_STAT_DESC=S.HR_STAT_DESC,
		WOS_FLAG=S.WOS_FLAG,
		WOS_FUTURE_FLAG=S.WOS_FUTURE_FLAG,
		JOB_IND=S.JOB_IND,
		EMP_CLASS=S.EMP_CLASS,
		EMP_CLASS_DESC=S.EMP_CLASS_DESC,
		CLASS_CD=S.CLASS_CD,
		CLASS_CD_DESC=S.CLASS_CD_DESC,
		END_DT=S.END_DT,
		AUTO_END=S.AUTO_END,
		JOB_DEPT=S.JOB_DEPT,
		DEPT_NAME=S.DEPT_NAME,
		[SCH/DIV]=S.[SCH/DIV],
		[SCH/DIV_DESC]=S.[SCH/DIV_DESC],
		PAY_GRP=S.PAY_GRP,
		SUPERVISOR=S.SUPERVISOR,
		REL=S.REL,
		REL_DESC=S.REL_DESC,
		EMAIL=S.EMAIL,
		CTO=S.CTO,
		CTO_DESC=S.CTO_DESC,
		ACAD_FLG=S.ACAD_FLG,
		MSP_FLG=S.MSP_FLG,
		SSP_FLG=S.SSP_FLG,
		SUPVR_FLG=S.SUPVR_FLG,
		MGR_FLG=S.MGR_FLG,
		STDT_FLG=S.STDT_FLG,
		FACULTY_FLG=S.FACULTY_FLG 
	WHEN NOT MATCHED BY TARGET THEN INSERT
	(
		NAME,
		LAST_NAME,
		FIRST_NAME,
		MIDDLE_NAME,
		NAME_PREFIX,
		NAME_SUFFIX,
		EMP_ID,
		PPS_ID,
		BIRTHDATE,
		EMP_HIGH_EDU_LVL_CD,
		EMP_HIGH_EDU_LVL_DESC,
		HIRE_DT,
		EMP_ORIG_HIRE_DT,
		EMP_WRK_PH_NUM,
		EMP_SPOUSE_FULL_NM,
		RPTS_TO_POSN_NBR_COUNT,
		EMP_RCD,
		EFF_DT,
		EFF_SEQ,
		JOBCODE,
		JOBCODE_DESC,
		PER_ORG,
		JOB_FUNCTION,
		JOB_FUNCTION_DESC,
		UNION_CD,
		POSN_NBR,
		RPTS_TO_POSN_NBR,
		SAL_ADMIN_PLAN,
		GRADE,
		STEP,
		EARNS_DIST_TYPE,
		STD_HOURS,
		STD_HRS_FREQUENCY,
		FTE,
		JOB_F_FTE_PCT,
		COMP_FREQUENCY,
		COMPRATE,
		ANNL_RATE,
		CALC_ANNUAL_RATE,
		EMP_STAT,
		EMPL_STAT_DESC,
		HR_STAT,
		HR_STAT_DESC,
		WOS_FLAG,
		WOS_FUTURE_FLAG,
		JOB_IND,
		EMP_CLASS,
		EMP_CLASS_DESC,
		CLASS_CD,
		CLASS_CD_DESC,
		END_DT,
		AUTO_END,
		JOB_DEPT,
		DEPT_NAME,
		[SCH/DIV],
		[SCH/DIV_DESC],
		PAY_GRP,
		SUPERVISOR,
		REL,
		REL_DESC,
		EMAIL,
		CTO,
		CTO_DESC,
		ACAD_FLG,
		MSP_FLG,
		SSP_FLG,
		SUPVR_FLG,
		MGR_FLG,
		STDT_FLG,
		FACULTY_FLG
	)
	VALUES
	(
		NAME,
		LAST_NAME,
		FIRST_NAME,
		MIDDLE_NAME,
		NAME_PREFIX,
		NAME_SUFFIX,
		EMP_ID,
		PPS_ID,
		BIRTHDATE,
		EMP_HIGH_EDU_LVL_CD,
		EMP_HIGH_EDU_LVL_DESC,
		HIRE_DT,
		EMP_ORIG_HIRE_DT,
		EMP_WRK_PH_NUM,
		EMP_SPOUSE_FULL_NM,
		RPTS_TO_POSN_NBR_COUNT,
		EMP_RCD,
		EFF_DT,
		EFF_SEQ,
		JOBCODE,
		JOBCODE_DESC,
		PER_ORG,
		JOB_FUNCTION,
		JOB_FUNCTION_DESC,
		UNION_CD,
		POSN_NBR,
		RPTS_TO_POSN_NBR,
		SAL_ADMIN_PLAN,
		GRADE,
		STEP,
		EARNS_DIST_TYPE,
		STD_HOURS,
		STD_HRS_FREQUENCY,
		FTE,
		JOB_F_FTE_PCT,
		COMP_FREQUENCY,
		COMPRATE,
		ANNL_RATE,
		CALC_ANNUAL_RATE,
		EMP_STAT,
		EMPL_STAT_DESC,
		HR_STAT,
		HR_STAT_DESC,
		WOS_FLAG,
		WOS_FUTURE_FLAG,
		JOB_IND,
		EMP_CLASS,
		EMP_CLASS_DESC,
		CLASS_CD,
		CLASS_CD_DESC,
		END_DT,
		AUTO_END,
		JOB_DEPT,
		DEPT_NAME,
		[SCH/DIV],
		[SCH/DIV_DESC],
		PAY_GRP,
		SUPERVISOR,
		REL,
		REL_DESC,
		EMAIL,
		CTO,
		CTO_DESC,
		ACAD_FLG,
		MSP_FLG,
		SSP_FLG,
		SUPVR_FLG,
		MGR_FLG,
		STDT_FLG,
		FACULTY_FLG 
	)
	WHEN NOT MATCHED BY SOURCE THEN  DELETE
	;

	EXEC usp_RebuildAllTableIndexes @TableName = ''UCPath_PersonJob''
'

	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT '
USE [PPSDataMart]
GO	
'
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;

	SELECT @TSQL = '
	-- Update emp class desc field with data from CAES_HCMODS as the description table is missing from 
	-- CAESAPP_HCMODS:
	UPDATE UCPath_PersonJob
	SET EMP_CLASS_DESC = t2.DESCRSHORT
	FROM UCPath_PersonJob t1
	INNER JOIN [UCPath_CAESAPP_HCMODS].[dbo].[PS_EMPL_CLASS_TBL] t2 ON t1.[EMP_CLASS] = t2.EMPL_CLASS AND t2.EFFDT = (
		SELECT MAX(EFFDT)
		FROM [UCPath_CAESAPP_HCMODS].[dbo].[PS_EMPL_CLASS_TBL] x
		WHERE t2.EMPL_CLASS = x.EMPL_CLASS AND
			t2.EFF_STATUS = x.EFF_STATUS AND
			x.EFFDT <= GETDATE()
			) AND t2.DML_IND <> ''D'' AND t2.EFF_STATUS = ''A''
'

	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;

	SELECT @TSQL = '
	-- Backfill some fields missing from ODS with values present in BIDWH:
	UPDATE UCPath_PersonJob
	SET COMPRATE = t2.[JOB_F_COMP_RT], 
		ANNL_RATE = JOB_F_ANNL_RT,
		JOB_F_FTE_PCT = t2.JOB_F_FTE_PCT,
		EMP_HIGH_EDU_LVL_CD = t2.EMP_HIGH_EDU_LVL_CD, 
		EMP_HIGH_EDU_LVL_DESC = t2.EMP_HIGH_EDU_LVL_DESC,
		EMP_ORIG_HIRE_DT = t2.EMP_ORIG_HIRE_DT,
		EMP_WRK_PH_NUM = t2.EMP_WRK_PH_NUM,
		EMP_SPOUSE_FULL_NM = t2.EMP_SPOUSE_FULL_NM
		--,HM_DEPT_CD =  t2.DEPT_CD,  -- These turned out to either match what my logic selected or to be incorrest
		--HM_DEPT_TTL = t2.DEPT_TTL
	FROM UCPath_PersonJob t1
	INNER JOIN (
		SELECT * FROM OPENQUERY([FIS_BIDWH_PRD (CAESAPP_DM_ETLUSER)],''
		SELECT EMP_ID, 
			JOB_F_EMP_REC_NUM, 
			JOB_F_EFF_SEQ_NUM, 
			EFF_DT,
			JOB_F_COMP_RT, 
			JOB_F_ANNL_RT, 
			JOB_F_FTE_PCT, -- This info is also available from PS_JOB_V
			EMP_HIGH_EDU_LVL_CD,  --  This info is also available from PS_PERS_DATA_EFFDT_V.HIGHEST_EDUC_LVL
			EMP_HIGH_EDU_LVL_DESC, -- This would have to be looked up from PSXLATITEM_V on EDUCATION_LVL
			EMP_ORIG_HIRE_DT,
			EMP_WRK_PH_NUM,
			EMP_SPOUSE_FULL_NM,
			DEPT_CD,
			DEPT_TTL
	FROM CAESAPP_DM.JOB_F_V job
	INNER JOIN CAESAPP_DM.EMPLOYEE_D_V emp ON EMP_D_CUR_KEY = emp.EMP_D_KEY AND
	EMP_EFF_STAT_CD = ''''A'''' AND EMP_EFF_DT = (
				SELECT MAX(EMP_EFF_DT)
				FROM CAESAPP_DM.EMPLOYEE_D_V emp2
				WHERE emp.EMP_ID = emp2.EMP_ID AND
					emp.EMP_D_KEY = emp2.EMP_D_KEY AND
					emp.EMP_EFF_STAT_CD = emp2.EMP_EFF_STAT_CD AND
					emp.EMP_EXPR_DT = emp2.EMP_EXPR_DT 
					AND emp2.EMP_EXPR_DT > SYSDATE  
			) 
	INNER JOIN CAESAPP_DM.ORGANIZATION_D_V org ON org.ORG_D_KEY = ORG_D_HM_CUR_KEY
		'')
	) t2 ON t1.EMP_ID = t2.EMP_ID AND 
			t1.EMP_RCD = t2.JOB_F_EMP_REC_NUM AND
			t1.EFF_SEQ = t2.JOB_F_EFF_SEQ_NUM AND 
			t1.EFF_DT = t2.EFF_DT
'
	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;

	SELECT @TSQL = '
	-- Clear out ampersand fillers and replace with a single space:
	UPDATE UCPath_PersonJob
	SET [EMP_WRK_PH_NUM] = '' ''
	WHERE [EMP_WRK_PH_NUM] LIKE ''&&&&&%''

	-- Try populating the phone number from RICE_UC_KRIM_PERSON:
	UPDATE UCPath_PersonJob
	SET [EMP_WRK_PH_NUM] = t2.PHONE_NBR
	FROM UCPath_PersonJob t1
	INNER JOIN [dbo].[RICE_UC_KRIM_PERSON] t2 ON t1.EMP_ID = t2.EMPLOYEE_ID
	WHERE 
		(t1.EMP_WRK_PH_NUM LIKE '' '' OR t1.EMP_WRK_PH_NUM IS NULL) AND
		(t2.PHONE_NBR IS NOT NULL AND t2.PHONE_NBR NOT LIKE '' '')

	-- Calculate the annual rate and set CALC_ANNUAL_RATE field:
	UPDATE UCPath_PersonJob 
	SET CALC_ANNUAL_RATE = (
		CASE WHEN FTE = 0 THEN 0
			 WHEN FTE = 1 THEN ANNL_RATE 
			 ELSE ROUND(ANNL_RATE / FTE,2)  END)

	-- Update any records with preferred names when present:
	UPDATE UCPath_PersonJob
	SET NAME = t2.Name, NAME_PREFIX = t2.NAME_PREFIX, LAST_NAME = t2.LAST_NAME, 
		FIRST_NAME = t2.FIRST_NAME, MIDDLE_NAME = t2.MIDDLE_NAME, NAME_SUFFIX = t2.NAME_SUFFIX
	FROM UCPath_PersonJob t1
	INNER JOIN (
		SELECT * FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
		SELECT EMPLID, NAME, NAME_PREFIX, LAST_NAME, FIRST_NAME, MIDDLE_NAME, NAME_SUFFIX
		FROM CAESAPP_HCMODS.ps_names_v names
						WHERE names.NAME_TYPE = ''''PRF''''
						AND names.EFFDT = (
							SELECT MAX(EFFDT)
							FROM CAESAPP_HCMODS.ps_names_v n
							WHERE names.EMPLID = n.EMPLID 
								AND names.NAME_TYPE = n.NAME_TYPE 
								AND n.EFFDT <= SYSDATE
								AND n.EFF_STATUS = ''''A''''
								AND n.DML_IND <> ''''D''''
						)
		'')
	) t2 ON t1.EMP_ID = t2.EMPLID
'
	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;

	-- Don't recall why I was doing this since it was set previously.
	--UPDATE PersonJob4
	--SET JOB_FUNCT_DESC = t2.DESCRSHORT
	--FROM PersonJob4 t1
	--INNER JOIN (
	--	SELECT * FROM OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],'
	--		SELECT JOB_FUNCTION, DESCRSHORT
	--		FROM CAES_HCMODS.PS_JOBFUNCTION_TBL_V jf
	--		WHERE EFF_STATUS = ''A'' AND
	--		EFFDT = (
	--			SELECT MAX(EFFDT) 
	--			FROM CAES_HCMODS.PS_JOBFUNCTION_TBL_V jf2
	--			WHERE jf.JOB_FUNCTION = jf2.JOB_FUNCTION AND
	--				jf.DML_IND = jf2.DML_IND AND
	--				jf.EFF_STATUS = jf2.EFF_STATUS AND
	--				jf2.EFFDT <= SYSDATE AND
	--				jf2.DML_IND <> ''D'' 
	--		 )
	--	')
	--) t2 ON t1.JOB_FUNCT = t2.JOB_FUNCTION

	SELECT @TSQL = '
	-- Reset the RPTS_TO_POSN_NBR_COUNT field 
	UPDATE UCPath_PersonJob
	SET RPTS_TO_POSN_NBR_COUNT = NULL

	-- Repopulate the RPTS_TO_POSN_NBR_COUNT field based on just loaded, i.e., current, data:
	UPDATE UCPath_PersonJob
	SET RPTS_TO_POSN_NBR_COUNT = t2.RPTS_TO_POSN_NBR_COUNT
	FROM UCPath_PersonJob t1
	INNER JOIN (
		SELECT DISTINCT t1.RPTS_TO_POSN_NBR, COUNT(*) RPTS_TO_POSN_NBR_COUNT
		FROM UCPath_PersonJob t1
		WHERE t1.RPTS_TO_POSN_NBR IS NOT NULL AND t1.RPTS_TO_POSN_NBR NOT LIKE '' ''
		AND t1.EMP_STAT != ''T'' AND t1.HR_STAT = ''A'' --AND t1.RPTS_TO_POSN_NBR = 40212049
		GROUP BY t1.RPTS_TO_POSN_NBR
	) t2 ON t1.POSN_NBR = t2.RPTS_TO_POSN_NBR --AND t1.POSN_NBR = 40212049
		AND t1.EMP_STAT != ''T'' AND t1.HR_STAT = ''A''

	-- I believe that we can use this because we filter out jobs that have a effdt > today,
	-- and the business rules state that this applies to current AND future jobs; 
	-- however, I believe that we truly only want to know if only all of their current jobs
	-- are WOS, and not worry about the future jobs until the current date is the future date.

	UPDATE UCPath_PersonJob
	SET WOS_FLAG = CASE WHEN all_job_count = WOS_job_count THEN ''Y'' ELSE ''N'' END
	FROM UCPath_PersonJob t1
	INNER JOIN (
		SELECT  COUNT(*) OVER (PARTITION BY job.emp_id) AS all_job_count, -- Count of employee''s total number of current and future jobs.
			t2.WOS_job_count,
			job.emp_id, PAY_GRP, emp_RCD, EFF_DT, EFF_SEQ
		  FROM UCPath_PersonJob job
		  INNER JOIN (
	  -- Count of employee''s current and future WOS paygroup jobs:
			  SELECT emp_id, count(*) WOS_job_count
			  FROM UCPath_PersonJob job 
			  WHERE 
				 HR_STAT = ''A'' 
				and PAY_GRP = ''WOS''
				AND EMP_STAT != ''T''
			  GROUP BY EMP_ID
	  ) t2 ON JOB.EMP_ID = t2.EMP_ID
	WHERE 
			HR_STAT = ''A'' AND EMP_STAT != ''T''
	) t2 ON t1.EMP_ID = t2.EMP_ID and t1.EMP_RCD = t2.EMP_RCD
'
	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;

	SELECT @TSQL = '
	UPDATE UCPath_PersonJob
	SET WOS_FUTURE_FLAG = CASE WHEN all_job_count = WOS_job_count THEN ''Y'' ELSE ''N'' END
	FROM UCPath_PersonJob t1
	INNER JOIN (
		SELECT * FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
			 SELECT  COUNT(*) OVER (PARTITION BY job.emplid) AS all_job_count, -- Count of employee''''s total number of current and future jobs.
					t2.WOS_job_count,
					job.emplid, paygroup, empl_RCD, EFFDT, EFFSEQ, PER_ORG
				  FROM CAESAPP_HCMODS.PS_JOB_V job
				  INNER JOIN (
			  -- Count of employee''''s current and future WOS paygroup jobs:
			  -- Note that we are making the assumption that any future job
			  -- has a unique emp_rec_num, and is not being currently used by
			  -- a current job!  Otherwise we''''l need another level that unions
			  -- together future jobs with current jobs.  Yuck!

					  SELECT emplid, count(*) WOS_job_count
					  FROM CAESAPP_HCMODS.PS_JOB_V job 
					  WHERE 
						HR_STATUS = ''''A'''' AND empl_status != ''''T''''
						AND EFFDT = (
							SELECT MAX(EFFDT)
							FROM CAESAPP_HCMODS.PS_JOB_V job2
							WHERE job.EMPLID = job2.emplid AND 
								job.EMPL_RCD = job2.EMPL_RCD  
								--AND job2.EFFDT <= sysdate -- We do not use this test here because the business rules say and current and FUTURE jobs.
								AND job2.DML_IND <> ''''D'''' 
						) AND
						EFFSEQ = (
							SELECT MAX(EFFSEQ)
							FROM CAESAPP_HCMODS.PS_JOB_V job3
							WHERE job.EMPLID = job3.emplid AND 
								job.EMPL_RCD = job3.EMPL_RCD AND 
								job.EFFDT = job3.EFFDT
								AND job3.DML_IND <> ''''D'''' 
						) and PAYGROUP = ''''WOS''''
						AND HR_STATUS = ''''A'''' AND empl_status != ''''T''''
					  GROUP BY EMPLID
			  ) t2 ON JOB.EMPLID = t2.EMPLID
			WHERE 
					HR_STATUS = ''''A'''' AND empl_status != ''''T'''' 
					AND EFFDT = (
						SELECT MAX(EFFDT)
						FROM CAESAPP_HCMODS.PS_JOB_V job2
						WHERE job.EMPLID = job2.emplid AND 
							job.EMPL_RCD = job2.EMPL_RCD  
							--AND job2.EFFDT <= sysdate -- We do not use this test here because the business rules say and current and FUTURE jobs.
							AND job2.DML_IND <> ''''D''''
				 
					) AND
					EFFSEQ = (
						SELECT MAX(EFFSEQ)
						FROM CAESAPP_HCMODS.PS_JOB_V job3
						WHERE job.EMPLID = job3.emplid AND 
							job.EMPL_RCD = job3.EMPL_RCD AND 
							job.EFFDT = job3.EFFDT
							AND job3.DML_IND <> ''''D''''
					) 
			'')
	)
	 t2 ON t1.EMP_ID = t2.emplid AND t1.EMP_RCD = t2.EMPL_RCD
'

	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;


	SELECT @TSQL = '
	UPDATE [UCPath_PersonJob]
	SET UCD_LOGIN_ID = t2.COMP_ACCT_USER_ID
	FROM [UCPath_PersonJob] t1
	INNER JOIN [PPSDataMart].[dbo].[RICE_UC_KRIM_PERSON] t2 ON t1.[EMP_ID] = t2.[EMPLOYEE_ID]

	UPDATE [UCPath_PersonJob]
	SET LEAVE_SERVICE_CREDIT = t2.UC_CURR_BAL
	FROM [UCPath_PersonJob] t1
	INNER JOIN (
		SELECT * FROM OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)] ,''
		SELECT * 
		FROM CAES_HCMODS.PS_UC_AM_SS_TBL_V t11
		WHERE
			t11.PIN_NUM = 260041 AND
			t11.ASOFDATE = (
				SELECT MAX(ta.ASOFDATE) 
				FROM CAES_HCMODS.PS_UC_AM_SS_TBL_V ta
				WHERE 
					t11.EMPLID = ta.EMPLID
					AND ta.PIN_NUM = 260041
					AND ta.ASOFDATE <= CURRENT_DATE
					AND ta.DML_IND <> ''''D'''' 
				) 	 
		'')
	) t2 ON t1.EMP_ID = t2.EMPLID

	-- Set the CALC_JOB_IND where there is no primary job indcated:
	-- And FTE <> 0:

		UPDATE [dbo].[UCPath_PersonJob]
		SET CALC_JOB_IND = JOB_IND2
		FROM [dbo].[UCPath_PersonJob]  t1
		INNER JOIN (
			SELECT CASE WHEN RowID = 1 THEN ''P'' ELSE JOB_IND END AS JOB_IND2, t1.*
			FROM (
				SELECT ROW_NUMBER() OVER (PARTITION BY EMP_ID ORDER BY FTE DESC) AS RowID,
				* FROM [dbo].[UCPath_PersonJob]
				WHERE HR_STAT = ''A'' AND FTE <> 0
				AND EMP_ID NOT IN (
					SELECT DISTINCT EMP_ID
					FROM [dbo].[UCPath_PersonJob]
					WHERE HR_STAT = ''A'' AND JOB_IND = ''P'' 
				)
			) t1
		) t2 ON t1.EMP_ID = t2.EMP_ID AND t1.EMP_RCD = t2.EMP_RCD
        
	-- And FTE = 0:

	UPDATE [dbo].[UCPath_PersonJob]
	SET CALC_JOB_IND = JOB_IND2
	FROM [dbo].[UCPath_PersonJob]  t1
	INNER JOIN (
  		  SELECT CASE WHEN RowID = 1 THEN ''P'' ELSE JOB_IND END AS JOB_IND2, t1.*
		  FROM (
			  SELECT ROW_NUMBER() OVER (PARTITION BY EMP_ID ORDER BY FTE,PER_ORG DESC, EMP_RCD) AS RowID,
			  * FROM [dbo].[UCPath_PersonJob]
			  WHERE HR_STAT = ''A'' AND FTE = 0
			  AND EMP_ID NOT IN (
				  SELECT DISTINCT EMP_ID
				  FROM [dbo].[UCPath_PersonJob]
				  WHERE HR_STAT = ''A'' AND JOB_IND = ''P'' 
			  )
		  ) t1
	 ) t2 ON t1.EMP_ID = t2.EMP_ID AND t1.EMP_RCD = t2.EMP_RCD
 '
	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;

END