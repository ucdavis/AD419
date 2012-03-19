﻿CREATE Procedure [dbo].[usp_DownloadDistributions]

AS

SELECT * FROM OPENQUERY(PAY_PERS_EXTR, '
	SELECT EMPLOYEE_ID, DIST_NUM, APPT_NUM, FAU_CHART, FAU_ACCT, FAU_SUBACCT, FAU_OBJECT, 
			FAU_SUBOBJ, FAU_PROJECT, FAU_OP_FUND, FAU_SUB_FUND_GRP_TYP_CD, FAU_SUB_FUND_GROUP_CD, 
			DIST_DEPT_CODE, FAU_ORG_CD, DIST_FTE, PAY_BEGIN_DATE, PAY_END_DATE, DIST_PERCENT, 
			DIST_PAYRATE, DIST_DOS, DIST_ADC_CODE, DIST_STEP, DIST_OFF_ABOVE, WORK_STUDY_PGM
	FROM EDBDIS_V
')
