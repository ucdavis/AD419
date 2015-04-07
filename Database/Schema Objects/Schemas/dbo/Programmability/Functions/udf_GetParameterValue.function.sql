﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: January 12, 2012
-- Description:	Given an input parameter and a default, return the appropriate value
-- Usage:
-- DECLARE @AdminTableNameDefault varchar(255) = 'AdminTable'
-- DECLARE @InputParamValue varchar(255) = '' -- The value passed in by the input parameter (if present)
-- DECLARE @DefaultValue varchar(255) = (SELECT @AdminTableNameDefault) -- The default value for the parameter if not passed in or present in the [dbo].[ParamNameAndValue] table
-- DECLARE @ParamVariableName varchar(255) = 'AdminTableName' -- The name of the variable if present in the [dbo].[ParamNameAndValue] table
--
-- SELECT  dbo.udf_GetParameterValue (@InputParamValue, @DefaultValue, @ParamVariableName )
-- SELECT dbo.udf_GetParameterValue ('MyPassedInParamValue', 'MyDefaultParamValue', 'MyVariableName' )
-- eg. SELECT dbo.udf_GetParameterValue ('TestAdminTable', 'AdminTable', 'AdminTableName')
-- eg. SELECT dbo.udf_GetParameterValue ('TestAdminTable', 'AdminTable', 'AdminTableName' )
--
-- Modifications:
-- 2014-12-17 by kjt: Removed database specific database references so it sp can be run against
--	another AD419 database, i.e. AD419_2014, etc.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetParameterValue] 
(
	-- Add the parameters for the function here
	@InputParamValue varchar(255), --The value of the input parameter
	@DefaultValue varchar(255), --The default value for the parameter
	@ParamVariableName varchar(255) --The variable name of the parameter as saved in TableNameVariableName column of [dbo].[ParameterNameAndValue]
)
RETURNS varchar(255)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @OutputParamValue varchar(255) = @InputParamValue

	-- Add the T-SQL statements to compute the return value here
	-- 1. use param if provided, else use database, else use default 
	IF @InputParamValue IS NULL OR @InputParamValue LIKE ''
	-- No param provided
		BEGIN	
		-- if table exists and value is not null of '' use table name's value
			IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ParamNameAndValue]') AND type in (N'U'))
				BEGIN
					SELECT @OutputParamValue = (SELECT ParamValue FROM [dbo].[ParamNameAndValue] WHERE [ParamName] = @ParamVariableName)
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
		
	-- Return the result of the function
	RETURN @OutputParamValue

END
