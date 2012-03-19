-- =============================================
-- Author:		Ken Taylor
-- Create date: January 12, 2012
-- Description:	Given an input parameter, default value, variable name, and variable table name, return the appropriate parameter value
-- NOTE: This version allows the database name, schema name and variable table name to be passed in.
-- Usage:
-- DECLARE @AdminTableNameDefault varchar(255) = 'AdminTable'
-- DECLARE @InputParamValue varchar(255) = '' -- The value passed in by the input parameter (if present)
-- DECLARE @DefaultValue varchar(255) = (SELECT @AdminTableNameDefault) -- The default value for the parameter if not passed in or present in the [AD419].[dbo].[TableName] table
-- DECLARE @ParamVariableName varchar(255) = 'AdminTableName' -- The name of the variable if present in the [AD419].[dbo].[ParamNameAndValue] table
-- DECLARE @DatabaseName varchar(50) = 'AD419' -- The name of the database where the variable table is located
-- DECLARE @SchemaName varchar(50) = 'dbo' -- The database schema, i.e. owner, where the variable table is located 
-- DECLARE @VariableNameTable varchar(255) = 'ParamNameAndValue' -- The name of the table where the variables are stored
--
-- eg. EXEC dbo.usp_GetParameterValue 'TestAdminTable', 'AdminTable', 'AdminTableName'
-- eg. EXEC dbo.usp_GetParameterValue 'TestAdminTable', 'AdminTable', 'AdminTableName', 'AD419', 'dbo', 'TableName'
-- eg. EXEC dbo.usp_GetParameterValue @InputParamValue = @InputParamValue, @DefaultValue = @DefaultValue, @ParamVariableName = @ParamVariableName, @VariableNameTable = @VariableNameTable, @IsDebug = 1
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetParameterValue] 
(
	-- Add the parameters for the function here
	@InputParamValue varchar(255), --The value of the input parameter
	@DefaultValue varchar(255), --The default value for the parameter
	@ParamVariableName varchar(255), --The variable name of the parameter as saved in ParamName column of [AD419].[dbo].[TableName]
	@DatabaseName varchar(50) = 'AD419', -- The name of the database where the variable table is located
	@SchemaName varchar(50) = 'dbo', -- The database schema, i.e. owner, where the variable table is located 
	@VariableNameTable varchar(255) = 'ParamNameAndValue', -- The name of the table where the variable names and values have been saved, i.e. [AD419].[dbo].[ParamNameAndValue]
	@IsDebug bit = 0 -- Set to 1 to display debug text; false otherwise.
)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @OutputParamValue varchar(255) = @InputParamValue
	DECLARE @Statement nvarchar(MAX)= ''
	DECLARE @Parameter_Definition NVARCHAR(MAX) = N'@OutputParamValue_OUT  varchar(255) OUTPUT'

	-- Add the T-SQL statements to compute the return value here
	-- 1. use param if provided, else use database, else use default 
	IF @InputParamValue IS NULL OR @InputParamValue LIKE ''
	-- No param provided
		BEGIN	
		-- if table exists and value is not null of '' use table name's value
			IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[' + @DatabaseName + '].[' + @SchemaName + '].[' + @VariableNameTable + ']') AND type in (N'U'))
				BEGIN
					SELECT @Statement = '
	SELECT @OutputParamValue_OUT = (SELECT ParamValue FROM [' + @DatabaseName + '].[' + @SchemaName + '].[' + @VariableNameTable + '] WHERE [ParamName] = ''' + @ParamVariableName + ''') 
'					IF @IsDebug = 1 PRINT @Statement
					EXEC sp_executesql @statement, @Parameter_Definition, @OutputParamValue_OUT = @OutputParamValue OUTPUT
					IF (@OutputParamValue IS NULL OR @OutputParamValue LIKE '') 
						BEGIN
						-- use default:
							SELECT @OutputParamValue = @DefaultValue
						END
				-- ELSE use table name's value
				END
			ELSE
			-- use default:
				SELECT @OutputParamValue = @DefaultValue
		END
	SELECT @OutputParamValue
END
