CREATE Procedure [dbo].[usp_UpdateDistributions]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS
--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

select @TSQL = 
	'merge PPSDataMart.dbo.Distributions Distributions
	using
	(
	SELECT 
		EMPLOYEE_ID, 
		DIST_NUM, 
		APPT_NUM, 
		FAU_CHART, 
		FAU_ACCT, 
		FAU_SUBACCT, 
		FAU_OBJECT, 
		FAU_SUBOBJ, 
		FAU_PROJECT, 
		FAU_OP_FUND, 
		FAU_SUB_FUND_GRP_TYP_CD, 
		FAU_SUB_FUND_GROUP_CD, 
		DIST_DEPT_CODE, 
		FAU_ORG_CD, DIST_FTE, 
		PAY_BEGIN_DATE, 
		PAY_END_DATE, 
		DIST_PERCENT, 
		DIST_PAYRATE, 
		DIST_DOS, 
		DIST_ADC_CODE, 
		DIST_STEP, 
		DIST_OFF_ABOVE, 
		WORK_STUDY_PGM
	 FROM OPENQUERY(PAY_PERS_EXTR, ''
		SELECT 
			EMPLOYEE_ID, 
			DIST_NUM, 
			APPT_NUM, 
			FAU_CHART, 
			FAU_ACCT, 
			FAU_SUBACCT, 
			FAU_OBJECT, 
			FAU_SUBOBJ, 
			FAU_PROJECT, 
			FAU_OP_FUND, 
			FAU_SUB_FUND_GRP_TYP_CD, 
			FAU_SUB_FUND_GROUP_CD, 
			DIST_DEPT_CODE, 
			FAU_ORG_CD, 
			DIST_FTE, 
			PAY_BEGIN_DATE, 
			PAY_END_DATE, 
			DIST_PERCENT, 
			DIST_PAYRATE, 
			DIST_DOS, 
			DIST_ADC_CODE, 
			DIST_STEP, 
			DIST_OFF_ABOVE, 
			WORK_STUDY_PGM
	FROM EDBDIS_V
'')
) EDBDIS_V on Distributions.EmployeeID = EDBDIS_V.EMPLOYEE_ID
	AND Distributions.DistNo = EDBDIS_V.DIST_NUM
	AND Distributions.ApptNo = EDBDIS_V.APPT_NUM
	
	WHEN MATCHED THEN UPDATE set
	   [Chart] = FAU_CHART
      ,[Account] = FAU_ACCT
      ,[SubAccount] = FAU_SUBACCT
      ,[Object] = FAU_OBJECT
      ,[SubObject] = FAU_SUBOBJ
      ,[Project] = FAU_PROJECT 
      ,[OPFund] = FAU_OP_FUND
      ,[SubFundGroupTypeCode] = FAU_SUB_FUND_GRP_TYP_CD
      ,[SubFundGroupCode] = FAU_SUB_FUND_GROUP_CD
      ,[DepartmentNo] = DIST_DEPT_CODE
      ,[OrgCode] = FAU_ORG_CD
      ,[FTE] = DIST_FTE
      ,[PayBegin] = PAY_BEGIN_DATE
      ,[PayEnd] = PAY_END_DATE
      ,[Percent] = DIST_PERCENT
      ,[PayRate] = DIST_PAYRATE
      ,[DOSCode] = DIST_DOS
      ,[ADCCode] = DIST_ADC_CODE
      ,[Step] = DIST_STEP
      ,[OffScaleCode] = DIST_OFF_ABOVE
      ,[WorkStudyPGM] = WORK_STUDY_PGM
      ,[IsInPPS] = 1
      
   WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      (
		EMPLOYEE_ID, 
		DIST_NUM, 
		APPT_NUM, 
		FAU_CHART, 
		FAU_ACCT, 
		FAU_SUBACCT, 
		FAU_OBJECT, 
		FAU_SUBOBJ, 
		FAU_PROJECT, 
		FAU_OP_FUND, 
		FAU_SUB_FUND_GRP_TYP_CD, 
		FAU_SUB_FUND_GROUP_CD, 
		DIST_DEPT_CODE, 
		FAU_ORG_CD, DIST_FTE, 
		PAY_BEGIN_DATE, 
		PAY_END_DATE, 
		DIST_PERCENT, 
		DIST_PAYRATE, 
		DIST_DOS, 
		DIST_ADC_CODE, 
		DIST_STEP, 
		DIST_OFF_ABOVE, 
		WORK_STUDY_PGM,
		1
      )
	WHEN NOT MATCHED BY SOURCE THEN UPDATE SET
	[IsInPPS] = 0
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
