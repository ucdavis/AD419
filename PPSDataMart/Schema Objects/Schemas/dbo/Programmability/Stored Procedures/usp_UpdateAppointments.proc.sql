CREATE Procedure [dbo].[usp_UpdateAppointments]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

print '-- Downloading Appointment records...'
	print '-- Selecting records from PAYROLL.EDBAPP_V'
	print '-- Update any matching records in the Appointments table where none have been updated previously.'
	print '-- IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True (Just display SQL. Don''t update anything)' ELSE 'False (Run script)' END
	print '-------------------------------------------------------------------------'

select @TSQL = 
	'merge PPSDataMart.dbo.Appointments Appointments
	using
	(
	SELECT 
		EMPLOYEE_ID, 
		APPT_NUM, 
		GRADE, 
		APPT_DEPT, 
		TITLE_CODE, 
		TITLE_UNIT_CODE, 
		ACADEMIC_BASIS, 
		APPT_PAID_OVER, 
		RETIREMENT_CODE, 
		FIXED_VAR_CODE, 
		APPT_TYPE, 
		APPT_ADC_CODE, 
		APPT_WOS_IND, 
		PERSONNEL_PGM,
		TIME_REPT_CODE, 
		LEAVE_ACRUCODE, 
		APPT_REP_CODE, 
		PERCENT_FULLTIME, 
		PAY_RATE, 
		PAY_SCHEDULE, 
		RATE_CODE, 
		APPT_BEGIN_DATE, 
		APPT_END_DATE, 
		APPT_DURATION 
	FROM OPENQUERY(PAY_PERS_EXTR, ''
		SELECT 
			EMPLOYEE_ID, 
			APPT_NUM, 
			GRADE, 
			APPT_DEPT, 
			TITLE_CODE, 
			TITLE_UNIT_CODE, 
			ACADEMIC_BASIS, 
			APPT_PAID_OVER, 
			RETIREMENT_CODE, 
			FIXED_VAR_CODE, 
			APPT_TYPE, 
			APPT_ADC_CODE, 
			APPT_WOS_IND, 
			PERSONNEL_PGM,
			TIME_REPT_CODE, 
			LEAVE_ACRUCODE, 
			APPT_REP_CODE, 
			PERCENT_FULLTIME, 
			PAY_RATE, 
			PAY_SCHEDULE, 
			RATE_CODE, 
			APPT_BEGIN_DATE, 
			APPT_END_DATE, 
			APPT_DURATION
		FROM EDBAPP_V
'')
) EDBAPP_V on Appointments.EmployeeID = EDBAPP_V.EMPLOYEE_ID AND Appointments.ApptNo = EDBAPP_V.APPT_NUM

	WHEN MATCHED THEN UPDATE set
		 [Grade]			= EDBAPP_V.GRADE 
		,[Department]	    = APPT_DEPT 
		,[TitleCode]	    = TITLE_CODE 
		,[TitleUnitCode]    = TITLE_UNIT_CODE 
		,[AcademicBasis]    = ACADEMIC_BASIS 
		,[PaidOver]			= APPT_PAID_OVER 
		,[RetirementCode]   = RETIREMENT_CODE 
		,[FixedVarCode]	    = FIXED_VAR_CODE 
	,[TypeCode]			= APPT_TYPE 
	,[ADCCode]			= APPT_ADC_CODE 
	,[WOSCode]			= APPT_WOS_IND 
	,[PersonnelProgram] = PERSONNEL_PGM
	,[TimeReportCode]   = TIME_REPT_CODE 
	,[LeaveAccrualCode] = LEAVE_ACRUCODE 
	,[RepresentedCode]  = APPT_REP_CODE 
	,[Percent]			= PERCENT_FULLTIME 
	,[PayRate]			= PAY_RATE 
	,[PaySchedule]	    = PAY_SCHEDULE 
	,[RateCode]			= RATE_CODE 
	,[BeginDate]	    = APPT_BEGIN_DATE 
	,[EndDate]			= APPT_END_DATE 
	,[Duration]			= APPT_DURATION
	,[IsInPPS]          = 1
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      (
		EMPLOYEE_ID, 
		APPT_NUM, 
		GRADE, 
		APPT_DEPT, 
		TITLE_CODE, 
		TITLE_UNIT_CODE, 
		ACADEMIC_BASIS, 
		APPT_PAID_OVER, 
		RETIREMENT_CODE, 
		FIXED_VAR_CODE, 
		APPT_TYPE, 
		APPT_ADC_CODE, 
		APPT_WOS_IND, 
		PERSONNEL_PGM,
		TIME_REPT_CODE, 
		LEAVE_ACRUCODE, 
		APPT_REP_CODE, 
		PERCENT_FULLTIME, 
		PAY_RATE, 
		PAY_SCHEDULE, 
		RATE_CODE, 
		APPT_BEGIN_DATE, 
		APPT_END_DATE, 
		APPT_DURATION,
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
