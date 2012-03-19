CREATE Procedure [dbo].[usp_UpdateDepartments]
(
	@FirstDate varchar(16) = null,
		--earliest date to download (Departments.HME_LAST_ACTION_DT) 
		--optional, defaults to highest date in dbo.Departments table
	@GetUpdatesOnly bit = 1, -- set to 0 if you want all the records since the first date.
							 --Only valid if a firstdate is provided.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

-- Changes:
-- 2010-12-06 by kjt: Added null fields for cluster columns.

--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

DECLARE @MaxDate DATETIME
SELECT @MaxDate = (SELECT MAX(LastActionDate) FROM PPSDataMart.dbo.Departments)

declare @MyDate smalldatetime	--temp holder of dates as type smalldatetime
		-- Note regarding date formats: Need to pass date to Oracle using it's conversion
		-- function TO_DATE, for which a string type is need.  I'm using a varchar for the
		-- parameters here, but convert to a smalldatetime in order to make use of the
		-- DateAdd() function and formatting options in the conversion function CONVERT.
		
--If no parameters passed, default to day after greatest date in Titles table, else use param value(s):
/*
	if @FirstDate IS NULL 
		--Attempt to read highest date in table currently and use this as @FirstDate value:
		BEGIN
			SELECT @MyDate = (SELECT cast(max(LastActionDate) as smalldatetime) as LastUpdateDate FROM Departments)
			SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
			--SELECT @FirstDate = convert(varchar(30),DateAdd(dd,1,@MyDate), 102)
		END
	else
		BEGIN
		
			SELECT @MyDate = convert(smalldatetime,@FirstDate)
			SELECT @MaxDate = @MyDate
			SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
		END
		*/
	IF @FirstDate IS NULL
		BEGIN
			IF @MaxDate IS NULL
				BEGIN
					Select 'Table is empty.  Loading All records.'
					SELECT @GetUpdatesOnly = 0
				END
			ELSE
				BEGIN
				--Attempt to read highest date in table currently and use this as @FirstDate value:
					SELECT @MyDate = (SELECT cast(@MaxDate as smalldatetime))  
					SELECT @MaxDate = @MyDate
					SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
				END
		END
	else
		BEGIN
			SELECT @MyDate = convert(smalldatetime,@FirstDate)
			IF @MaxDate IS NULL
				Select @GetUpdatesOnly = 0
			SELECT @MaxDate = @MyDate
			SELECT @FirstDate = convert(varchar(30), @MyDate, 102)
		END
	print '-- Downloading Department records...'
	IF @GetUpdatesOnly = 1
		BEGIN
			print '-- Selecting records from PAYROLL.CTVHME where CTVHME.HME_LAST_ACTION_DT >= ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102) + ' (Earliest Date)'
			print '-- Update any matching records in the titles table where none have been updated previously'
			print '--  or where the PAYROLL.CTVHME.HME_LAST_ACTION_DT > ' + ISNULL(Convert(varchar(30), @MaxDate, 110), 'N/A') + '.'
		END
	ELSE
		BEGIN
			Print '-- Selecting all records from PAYROLL.CTVHME'
		END
	print '-- IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True (Just display SQL. Don''t update anything)' ELSE 'False (Run script)' END
	print '-------------------------------------------------------------------------'
	
select @TSQL = 
	'merge PPSDataMart.dbo.Departments Departments
	using
	(
	SELECT 
		HME_DEPT_NO, 
		HME_DEPT_NAME, 
		HME_ABRV_DEPT_NAME, 
		UCD_SCHOOL_DIVISION, 
		HME_DEPT_MAIL_CODE, 
		HME_ORG_UNIT_CD, 
		HME_LAST_ACTION_DT 
	 FROM OPENQUERY(PAY_PERS_EXTR, ''
		SELECT 
			HME_DEPT_NO, 
			HME_DEPT_NAME, 
			HME_ABRV_DEPT_NAME, 
			UCD_SCHOOL_DIVISION, 
			HME_DEPT_MAIL_CODE, 
			HME_ORG_UNIT_CD, 
			HME_LAST_ACTION_DT 
		FROM PAYROLL.CTVHME
		'
		
		IF @GetUpdatesOnly = 1
			Select @TSQL += ' WHERE (CTVHME.HME_LAST_ACTION_DT >= TO_DATE(''''' + @FirstDate  + ''''' ,''''yyyy.mm.dd''''))
'')
WHERE (HME_LAST_ACTION_DT IS NULL OR HME_LAST_ACTION_DT >= ''' + Convert(varchar(30), @MaxDate, 101) + ''') '
		ELSE
			Select @TSQL += ' '')'
	Select @TSQL += '
	) CTVHME on Departments.HomeDeptNo = CTVHME.HME_DEPT_NO

	WHEN MATCHED THEN UPDATE set
	   [Name] = HME_DEPT_NAME
      ,[Abbreviation] = HME_ABRV_DEPT_NAME
      ,[SchoolCode] = UCD_SCHOOL_DIVISION
      ,[MailCode] = HME_DEPT_MAIL_CODE
      ,[HomeOrgUnitCode] = HME_ORG_UNIT_CD
      ,[LastActionDate] = HME_LAST_ACTION_DT
      
    WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      (
		HME_DEPT_NO, 
		HME_DEPT_NAME, 
		HME_ABRV_DEPT_NAME, 
		UCD_SCHOOL_DIVISION, 
		NULL,
		HME_DEPT_MAIL_CODE, 
		HME_ORG_UNIT_CD, 
		NULL,
		HME_LAST_ACTION_DT 
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
