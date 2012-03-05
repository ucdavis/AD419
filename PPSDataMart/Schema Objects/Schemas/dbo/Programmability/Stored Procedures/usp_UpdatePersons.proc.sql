CREATE Procedure [dbo].[usp_UpdatePersons]
(
	@FirstDate varchar(16) = null,
		--earliest date to download (PERSONS.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in dbo.Persons table
	@GetUpdatesOnly bit = 1, -- set to 0 if you want all the records since the first date.
							 --Only valid if a firstdate is provided.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS
--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

DECLARE @MaxDate DATETIME
SELECT @MaxDate = (SELECT MAX(LastChangeDate) FROM PPSDataMart.dbo.Persons)

DECLARE @TableIsEmpty bit = 0
IF @MaxDate IS NULL 
	Select @TableIsEmpty = 1

declare @MyDate smalldatetime	--temp holder of dates as type smalldatetime
		-- Note regarding date formats: Need to pass date to Oracle using it's conversion
		-- function TO_DATE, for which a string type is need.  I'm using a varchar for the
		-- parameters here, but convert to a smalldatetime in order to make use of the
		-- DateAdd() function and formatting options in the conversion function CONVERT.
		
--If no parameters passed, default to day after greatest date in Persons table, else use param value(s):
	if @FirstDate IS NULL 
		--Attempt to read highest date in table currently and use this as @FirstDate value:
		IF @MaxDate IS NOT NULL
			BEGIN
				SELECT @MyDate = (SELECT cast(@MaxDate as smalldatetime))
				SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
				--SELECT @FirstDate = convert(varchar(30),DateAdd(dd,1,@MyDate), 102)
			END
		ELSE
			BEGIN
				--Table is empty; download everything
				Select @GetUpdatesOnly = 0
			END
	else
		BEGIN
			SELECT @MyDate = convert(smalldatetime,@FirstDate)
			SELECT @MaxDate = @MyDate
			SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
		END
		
	print '-- Downloading Persons records...'
	IF @GetUpdatesOnly = 1
	BEGIN
		print '-- Selecting records from EDBPER_V where EDBPER_V.LAST_CHG_DATE >= ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102) + ' (Earliest Date)'
		print '-- Update any matching records in the persons table where none have been updated previously'
		print '--  or where the EDBPER_V.LAST_CHG_DATE > ' + Convert(varchar(30), @MaxDate, 110) + '.'
	END
	ELSE
		print '-- Selecting all records from EDBPER_V'
		
	print '-- IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True (Just display SQL. Don''t update anything)' ELSE 'False (Run script)' END
	print '-------------------------------------------------------------------------'
	
select @TSQL = 
	'merge PPSDataMart.dbo.Persons Persons
	using
	(
SELECT EMPLOYEE_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME, EMP_NAME, NAMESUFFIX, BIRTH_DATE,
				UCD_MAILID, UCDLOGINID, HOME_DEPT, ALT_DEPT_CD, UCD_ADMIN_DEPT, SCHOOL_DIVISION,
				PRIMARY_TITLE, PRIMARY_APPT_NUM, PRIMARY_DIST_NUM, JOB_GROUP_ID, HIRE_DATE, ORIG_HIRE_DATE,
				EMP_STATUS, STUDENT_STATUS, EDU_LEVEL, EMP_REL_UNIT, EMPLMT_CREDIT, SUPERVISOR, LAST_CHG_DATE FROM OPENQUERY(PAY_PERS_EXTR, ''
	SELECT EMPLOYEE_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME, EMP_NAME, NAMESUFFIX, BIRTH_DATE,
				UCD_MAILID, UCDLOGINID, HOME_DEPT, ALT_DEPT_CD, UCD_ADMIN_DEPT, SCHOOL_DIVISION,
				PRIMARY_TITLE, PRIMARY_APPT_NUM, PRIMARY_DIST_NUM, JOB_GROUP_ID, HIRE_DATE, ORIG_HIRE_DATE,
				EMP_STATUS, STUDENT_STATUS, EDU_LEVEL, EMP_REL_UNIT, EMPLMT_CREDIT, SUPERVISOR, LAST_CHG_DATE
	FROM EDBPER_V'
	
	IF @GetUpdatesOnly = 1
		SELECT @TSQL += '
	WHERE (EDBPER_V.LAST_CHG_DATE >= TO_DATE(''''' + @FirstDate  + ''''' ,''''yyyy.mm.dd''''))
'')
WHERE (LAST_CHG_DATE IS NULL OR LAST_CHG_DATE >= ''' + Convert(varchar(30), @MaxDate, 101) + ''')
 --( Last_Update_Date is null OR Last_Update_Date >= ''' + convert(varchar(30), @MaxDate, 101) + ''')
 '
	ELSE
		SELECT @TSQL += ' '') '
		
SELECT @TSQL += '
) PAYPERSEXTR on Persons.EmployeeID = PAYPERSEXTR.EMPLOYEE_ID

	WHEN MATCHED THEN UPDATE set
	[FirstName] = FIRST_NAME
      ,[MiddleName] = MIDDLE_NAME
      ,[LastName] = LAST_NAME
      ,[FullName] = EMP_NAME
      ,[Suffix] = NAMESUFFIX
      ,[BirthDate] = BIRTH_DATE
      ,[UCDMailID] = UCD_MAILID
      ,[UCDLoginID] = PAYPERSEXTR.UCDLOGINID
      ,[HomeDepartment] = HOME_DEPT
      ,[AlternateDepartment] = ALT_DEPT_CD
      ,[AdministrativeDepartment] = UCD_ADMIN_DEPT
      ,[SchoolDivision] = SCHOOL_DIVISION
      ,[PrimaryTitle] = PRIMARY_TITLE
      ,[PrimaryApptNo] = PRIMARY_APPT_NUM
      ,[PrimaryDistNo] = PRIMARY_DIST_NUM
      ,[JobGroupID] = JOB_GROUP_ID
      ,[HireDate] = HIRE_DATE
      ,[OriginalHireDate] = ORIG_HIRE_DATE
      ,[EmployeeStatus] = EMP_STATUS
      ,[StudentStatus] = STUDENT_STATUS
      ,[EducationLevel] = EDU_LEVEL
      ,[BarganingUnit] = EMP_REL_UNIT
      ,[LeaveServiceCredit] = EMPLMT_CREDIT
      ,[Supervisor] = PAYPERSEXTR.SUPERVISOR
      ,[LastChangeDate] = LAST_CHG_DATE
      ,[IsInPPS] = 1
      
    WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      (
      EMPLOYEE_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME, EMP_NAME, NAMESUFFIX, BIRTH_DATE,
				UCD_MAILID, UCDLOGINID, HOME_DEPT, ALT_DEPT_CD, UCD_ADMIN_DEPT, SCHOOL_DIVISION,
				PRIMARY_TITLE, PRIMARY_APPT_NUM, PRIMARY_DIST_NUM, JOB_GROUP_ID, HIRE_DATE, ORIG_HIRE_DATE,
				EMP_STATUS, STUDENT_STATUS, EDU_LEVEL, EMP_REL_UNIT, EMPLMT_CREDIT, SUPERVISOR, LAST_CHG_DATE, 1
      )
	-- WHEN NOT MATCHED BY SOURCE THEN DELETE
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
