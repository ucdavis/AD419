CREATE Procedure [dbo].[usp_UpdateTitleGroups]
(
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.

	print '-- Downloading All TitleGroup records...'
	print '-- IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True (Just display SQL. Don''t update anything)' ELSE 'False (Run script)' END
	print '-------------------------------------------------------------------------'
	

	select @TSQL = 
	'
	TRUNCATE TABLE PPSDataMart.dbo.TitleGroups;
	
	merge PPSDataMart.dbo.TitleGroups TitleGroups
	using
	(
	SELECT JGD_ID, JGD_FULL_DESC, JGD_ABBREV_DESC, JGD_LAST_ACTION_DT
	FROM OPENQUERY(PAY_PERS_EXTR, ''
		SELECT JGD_ID, JGD_FULL_DESC, JGD_ABBREV_DESC, JGD_LAST_ACTION_DT
		FROM PAYROLL.CTLJGD
'')
) CTLJGD on TitleGroups.JobGroupID = CTLJGD.JGD_ID

	WHEN MATCHED THEN UPDATE set
		[Description] = JGD_FULL_DESC
		,[Abbreviation] = JGD_ABBREV_DESC
		,LastActionDate = JGD_LAST_ACTION_DT
	
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
	(
		JGD_ID, JGD_FULL_DESC, JGD_ABBREV_DESC, JGD_LAST_ACTION_DT
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
