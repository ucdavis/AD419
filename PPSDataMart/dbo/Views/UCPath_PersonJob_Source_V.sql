

--=================================================================================
-- Created By: Ken Taylor
-- Creation Date: Aughst 4, 2021
-- Description: This view was created because of the desire to use the OPENQUERY text in conjunction
--		with dynamic SQL.  However, the OPENQUERY text (below) nearly exceeds the varchar(MAX) limitations.
--		Therefore, I have exported it to this view so that the MERGE statement may be used and not
--		exceed these limitations.
-- Notes: This view does NOT contain all of the fields present in the UCPath_PersonJob table, as is
--		typical with my standard table/view scenario; therefore, I renamed it to UCPath_PersonJob_Source_V instead.  
-- Usage: 
/*

	USE [PPSDataMart]
	GO

	SELECT * FROM [dbo].[UCPath_PersonJob_Source_V]

*/
-- Modifications: 
--	2021-08-04 by kjt: Expanded text so query would be more understandable.
--
--=================================================================================

CREATE VIEW [dbo].[UCPath_PersonJob_Source_V]
AS
SELECT        NAME, NAME_PREFIX, LAST_NAME, FIRST_NAME, MIDDLE_NAME, NAME_SUFFIX, EMP_ID, PPS_ID, BIRTHDATE, EMP_HIGH_EDU_LVL_CD, EMP_HIGH_EDU_LVL_DESC, HIRE_DT, EMP_ORIG_HIRE_DT, 
                         EMP_WRK_PH_NUM, EMP_SPOUSE_FULL_NM, RPTS_TO_POSN_NBR_COUNT, EMP_RCD, EFF_DT, EFF_SEQ, JOBCODE, JOBCODE_DESC, PER_ORG, JOB_FUNCTION, JOB_FUNCTION_DESC, UNION_CD, POSN_NBR, 
                         RPTS_TO_POSN_NBR, SAL_ADMIN_PLAN, GRADE, STEP, EARNS_DIST_TYPE, STD_HOURS, STD_HRS_FREQUENCY, FTE, JOB_F_FTE_PCT, COMP_FREQUENCY, COMPRATE, ANNL_RATE, CALC_ANNUAL_RATE, EMP_STAT, 
                         EMPL_STAT_DESC, HR_STAT, HR_STAT_DESC, WOS_FLAG, WOS_FUTURE_FLAG, JOB_IND, EMP_CLASS, EMP_CLASS_DESC, CLASS_CD, CLASS_CD_DESC, END_DT, AUTO_END, JOB_DEPT, DEPT_NAME, [SCH/DIV], 
                         [SCH/DIV_DESC], PAY_GRP, SUPERVISOR, REL, REL_DESC, EMAIL, CTO, CTO_DESC, ACAD_FLG, MSP_FLG, SSP_FLG, SUPVR_FLG, MGR_FLG, STDT_FLG, FACULTY_FLG
FROM            OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], 
                         '
select DISTINCT
	names.name NAME,
	names.NAME_PREFIX,
	names.LAST_NAME,
	names.FIRST_NAME,
	names.MIDDLE_NAME,
	names.NAME_SUFFIX,
	job.emplid EMP_ID,
	extsys.uc_ext_system_id PPS_ID,
	person.BIRTHDATE,
	CAST(NULL AS varchar(2)) AS EMP_HIGH_EDU_LVL_CD,
	CAST(NULL AS varchar(30)) EMP_HIGH_EDU_LVL_DESC,HIRE_DT,
	CAST(NULL AS DATE) EMP_ORIG_HIRE_DT,
	CAST(NULL AS varchar(24)) EMP_WRK_PH_NUM,
	CAST(NULL AS VARCHAR(50)) EMP_SPOUSE_FULL_NM,
	CAST(NULL AS int) RPTS_TO_POSN_NBR_COUNT,
	job.empl_rcd EMP_RCD,
	job.effdt EFF_DT,
	job.effseq EFF_SEQ,
	job.jobcode JOBCODE,
	jobcode1.descr JOBCODE_DESC,
	job.PER_ORG,
	jobcode1.JOB_FUNCTION,
	jobfunct.DESCR JOB_FUNCTION_DESC,
	job.UNION_CD,
	job.POSITION_NBR POSN_NBR,
	job.REPORTS_TO RPTS_TO_POSN_NBR,
	job.SAL_ADMIN_PLAN,
	job.GRADE,
	job.STEP,
	job.EARNS_DIST_TYPE,
	job.STD_HOURS,
	job.STD_HRS_FREQUENCY,
	job.FTE,
	CAST(NULL AS NUMBER(7,6)) JOB_F_FTE_PCT,
	job.COMP_FREQUENCY,
	CAST(NULL AS NUMBER(18,6)) COMPRATE,
	CAST(NULL AS NUMBER(18,3)) ANNL_RATE,
	CAST(NULL AS NUMBER(18,3)) CALC_ANNUAL_RATE,
	job.empl_status EMP_STAT,
	xlat1.xlatshortname EMPL_STAT_DESC,
	job.HR_STATUS HR_STAT,
	xlat3.xlatshortname HR_STAT_DESC,
	flags.emp_wosemp_flg WOS_FLAG,
	flags.emp_wosemp_flg WOS_FUTURE_FLAG,
	job.job_indicator JOB_IND,
	job.empl_class EMP_CLASS,
	CAST(NULL AS varchar(10)) EMP_CLASS_DESC,
	job.class_indc CLASS_CD,
	xlat2.xlatshortname CLASS_CD_DESC,
	job.expected_end_date END_DT,
	job.auto_end_flg AUTO_END,
	job.deptid JOB_DEPT,
	upper(org.dept_ttl) DEPT_NAME,
	org.SUB_DIV_CD "SCH/DIV",
	org.sub_div_ttl "SCH/DIV_DESC",
	job.paygroup PAY_GRP,
	CASE WHEN ucpos.uc_emp_rel_cd IN (''A'',''B'',''C'',''D'') OR cto.UC_CTO_OS_CD IN (''S21'',''S24'',''S31'',''S44'',''M10'')
	    THEN ''Y'' ELSE ''N''
	END AS SUPERVISOR,
	ucpos.uc_emp_rel_cd REL,
	xlat122.XLATLONGNAME AS REL_DESC,
	email.email_addr EMAIL,
	ucjob.uc_cto_os_cd CTO,
	cto.descr50 CTO_DESC,
	flags.emp_acdmc_flg ACAD_FLG,
	flags.emp_msp_flg MSP_FLG,
	flags.emp_ssp_flg SSP_FLG,
	flags.EMP_SUPVR_FLG SUPVR_FLG,
	flags.EMP_MGR_FLG MGR_FLG,
	flags.EMP_ACDMC_STDT_FLG STDT_FLG,
	flags.EMP_FACULTY_FLG FACULTY_FLG
from CAESAPP_HCMODS.ps_job_v job
	inner join CAESAPP_HCMODS.ps_person_v person on job.emplid = person.emplid
	inner join CAESAPP_HCMODS.ps_names_v names on 
	    job.emplid = names.emplid AND 
	    names.NAME_TYPE = ''PRI'' AND 
		names.EFFDT = (
		    SELECT MAX(EFFDT) 
		    FROM CAESAPP_HCMODS.ps_names_v n 
		    WHERE names.EMPLID = n.EMPLID AND 
		    names.NAME_TYPE = n.NAME_TYPE AND 
		    n.EFFDT <= SYSDATE AND 
		    n.EFF_STATUS = ''A''
		 ) AND 
		names.DML_IND <> ''D''
	inner join CAESAPP_HCMODS.ps_email_addresses_v email on 
	    job.emplid = email.emplid and 
	    email.e_addr_type = ''BUSN'' AND 
	    email.DML_IND <> ''D''
	left outer join CAESAPP_HCMODS.ps_uc_ext_system_v extsys on 
	    job.emplid = extsys.emplid and 
	    extsys.uc_ext_system = ''PPS_ID'' AND 
	    extsys.business_unit = ''DVCMP'' AND 
	    extsys.DML_IND <> ''D''
	inner join CAESAPP_HCMODS.ucd_organization_d_v org on job.deptid = org.dept_cd
	inner join CAESAPP_HCMODS.psxlatitem_v xlat1 on 
	    xlat1.fieldvalue = job.empl_status and 
	    xlat1.fieldname = ''EMPL_STATUS'' and 
	    xlat1.eff_status = ''A'' and            
		xlat1.effdt = (
		    select max(xlat1b.effdt) 
		    from CAESAPP_HCMODS.psxlatitem_v xlat1b 
		    where xlat1b.fieldvalue = xlat1.fieldvalue and 
		        xlat1b.fieldname = ''EMPL_STATUS'' and 
		        xlat1b.eff_status = ''A''
		) AND 
		xlat1.DML_IND <> ''D''
	inner join CAESAPP_HCMODS.psxlatitem_v xlat3 on 
	    xlat3.fieldvalue = job.hr_status and 
	    xlat3.fieldname = ''HR_STATUS'' and 
	    xlat3.eff_status = ''A'' and
		xlat3.effdt = (
		    select max(xlat3b.effdt) 
		    from CAESAPP_HCMODS.psxlatitem_v xlat3b 
		    where xlat3b.fieldvalue = xlat3.fieldvalue and 
		        xlat3b.fieldname = ''HR_STATUS'' and 
		        xlat3b.eff_status = ''A''
	    ) AND 
	    xlat3.DML_IND <> ''D''
	LEFT OUTER join CAESAPP_HCMODS.ps_uc_pos_emp_rel_v ucpos on 
	    ucpos.position_nbr = job.position_nbr and 
	    ucpos.effdt = (
	        select max(ucpos2.effdt)
			from CAESAPP_HCMODS.ps_uc_pos_emp_rel_v ucpos2 
			where ucpos2.position_nbr = ucpos.position_nbr) AND 
			    ucpos.DML_IND <> ''D''
	LEFT OUTER join CAESAPP_HCMODS.psxlatitem_v xlat122 on 
	    xlat122.fieldvalue = ucpos.uc_emp_rel_cd and 
	    xlat122.fieldname = ''UC_EMP_REL_CD'' and 
	    xlat122.eff_status = ''A'' and 
	    xlat122.effdt = (
	        select max(xlat122b.effdt) 
	        from CAESAPP_HCMODS.psxlatitem_v xlat122b 
	        where xlat122b.fieldvalue = xlat122.fieldvalue and 
	            xlat122b.fieldname = ''UC_EMP_REL_CD'' and 
	            xlat122b.eff_status = ''A''
	    ) AND 
	    xlat122.DML_IND <> ''D''    
	inner join CAESAPP_HCMODS.psxlatitem_v xlat2 on 
	    xlat2.fieldvalue = job.class_indc and 
	    xlat2.fieldname = ''CLASS_INDC'' and 
	    xlat2.eff_status = ''A'' and
		xlat2.effdt = (
		    select max(xlat2b.effdt) 
		    from CAESAPP_HCMODS.psxlatitem_v xlat2b 
		    where xlat2b.fieldvalue = xlat2.fieldvalue and 
		        xlat2b.fieldname = ''CLASS_INDC'' and 
		        xlat2b.eff_status = ''A''
	    ) and
	    xlat2.DML_IND <> ''D''
	inner join CAESAPP_HCMODS.PS_JOBCODE_TBL_V jobcode1 on 
	    job.jobcode = jobcode1.jobcode and 
	    jobcode1.eff_status = ''A'' and
		jobcode1.effdt = (
		    select max(jobcode2.effdt) 
		    from CAESAPP_HCMODS.PS_JOBCODE_TBL_V jobcode2
		    where jobcode1.jobcode = jobcode2.jobcode and 
		        jobcode2.eff_status = ''A''
		) AND 
		jobcode1.DML_IND <> ''D''
	LEFT OUTER join CAESAPP_HCMODS.ps_uc_pos_emp_rel_v ucpos on 
	    ucpos.position_nbr = job.position_nbr and 
	    ucpos.effdt = (
	        select max(ucpos2.effdt)
			from CAESAPP_HCMODS.ps_uc_pos_emp_rel_v ucpos2 
			where ucpos2.position_nbr = ucpos.position_nbr
		) AND 
		ucpos.DML_IND <> ''D''
	inner join CAESAPP_HCMODS.ps_uc_job_codes_v ucjob on 
	    ucjob.jobcode = job.jobcode and 
	    ucjob.setid = ''UCSHR'' and 
	    ucjob.effdt = (
	        select max(ucjob2.effdt) 
	        from CAESAPP_HCMODS.ps_uc_job_codes_v ucjob2 
	        where ucjob2.jobcode = ucjob.jobcode and
		        ucjob2.setid = ''UCSHR''
		) AND
		 ucjob.DML_IND <> ''D''
	inner join CAESAPP_HCMODS.ps_uc_cto_osc_v cto on 
	    ucjob.uc_cto_os_cd = cto.uc_cto_os_cd and 
	    cto.eff_status = ''A'' and 
		cto.effdt = (
		    select max(cto2.effdt) 
		    from CAESAPP_HCMODS.ps_uc_cto_osc_v cto2 
		    where cto2.uc_cto_os_cd = cto.uc_cto_os_cd and 
		        cto2.eff_status = ''A''
		) AND 
		cto.DML_IND <> ''D''
	inner join CAESAPP_HCMODS.ucd_employee_flags_d_v flags on job.emplid = flags.emp_id
	left outer join CAESAPP_HCMODS.PS_JOBFUNCTION_TBL_V jobfunct ON 
	    jobcode1.JOB_FUNCTION = jobfunct.JOB_FUNCTION AND 
	    jobfunct.EFF_STATUS = ''A'' AND
	    jobfunct.EFFDT = (
	        SELECT MAX(EFFDT) 
	        FROM CAESAPP_HCMODS.PS_JOBFUNCTION_TBL_V jobfunct2
		    WHERE jobfunct.JOB_FUNCTION = jobfunct2.JOB_FUNCTION AND 
		        jobfunct2.EFF_STATUS = ''A'' AND 
		        jobfunct2.EFFDT <= SYSDATE AND 
		        jobfunct2.DML_IND <> ''D''
	    ) 
	where
		job.effdt = (
		    select max(job2.effdt) 
		    from CAESAPP_HCMODS.ps_job_v job2 
		    where job.emplid = job2.emplid and 
				job.empl_rcd = job2.empl_rcd and 
				job2.effdt <= sysdate and 
				job2.dml_ind <> ''D'' 
		) and
		job.effseq = ( 
		    select max(job3.effseq) 
		    from CAESAPP_HCMODS.ps_job_v JOB3 
		    where job.emplid = job3.emplid and 
				job.empl_rcd = job3.empl_rcd and 
				job3.effdt = job.effdt and 
				job3.dml_ind <> ''D''
		) 
	order by names.name, job.emplid, extsys.uc_ext_system_id, job.empl_rcd, job.effdt, job.effseq, job.job_indicator
') AS derivedtbl_1