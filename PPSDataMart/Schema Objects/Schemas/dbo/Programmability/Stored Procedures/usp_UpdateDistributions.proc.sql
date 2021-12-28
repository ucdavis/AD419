
/*
Usage:
	
	EXEC usp_UpdateDistributions @IsDebug = 1

Modifications:
	-- 2017-08-03 by kjt: Removed updating the PayBegin and PayEnd date so that we could 
	-- have some historical records for use with testing AD-419; otherwise, the date was 
	-- being updated and we lost this capability.
	-- 2017-10-23 by kjt: Fixed join columns so that data join would also consider null dates in both
	-- columns as well matching dates because date = date by itself does not work if both old and new date
	-- data are both null, meaning it will consider it a new record and attempt to insert it, 
	-- as opposed to updating an existing one.  This was causing a failure because of a duplicate key issue. 

*/
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
	AND Distributions.DistNo	= EDBDIS_V.DIST_NUM
	AND Distributions.ApptNo	= EDBDIS_V.APPT_NUM
	AND (Distributions.PayBegin = EDBDIS_V.PAY_BEGIN_DATE OR (Distributions.PayBegin IS NULL AND EDBDIS_V.PAY_BEGIN_DATE IS NULL))
	AND (Distributions.PayEnd	= EDBDIS_V.PAY_END_DATE OR (Distributions.PayEnd IS NULL AND EDBDIS_V.PAY_END_DATE IS NULL))
	
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
      --,[PayBegin] = PAY_BEGIN_DATE
      --,[PayEnd] = PAY_END_DATE
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
