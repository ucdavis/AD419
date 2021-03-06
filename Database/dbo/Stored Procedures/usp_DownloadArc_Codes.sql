﻿
-- =============================================
-- Author:		Ken Taylor
-- Create date: September 15, 2016
-- Description:	Update the FISDataMart ARC_Codes table 
-- from the DaFIS FINANCE.ANNUAL_REPORT_CODE table.
-- This version facilitates the call the actual stored procedure on FISDataMart database in a manner
-- similar to the other stored procedures called by AD419DataHelper program.
-- Usage:
/*
	USE [AD419]
	GO

	EXEC [dbo].[usp_DownloadArc_Codes]
	@FiscalYear = 2015, -- Just used as a place holder.
	@IsDebug = 1

	GO
*/
--
-- NOTE: Run this prior to updating the isAES flag based on AD419 Schedule C provided by Steve Pesis.
--
-- Modifications:
--	20160128 by kjt: Added 2 additional columns: ARC_CATEGORY_CD, and ARC_SUB_CATEGORY_CD.
--	20160331 by kjt: Added VM ARCs to exclusion list.
CREATE PROCEDURE [dbo].[usp_DownloadArc_Codes]
	@FiscalYear int = 2015, -- Unused.  Just provided as a place holder.  
	@IsDebug bit = 0 -- Set to 1 to print SQL generated by script only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TableName varchar(255) = 'ARC_Codes' -- Optional ARC codes table name if different from default. 
	DECLARE @TSQL varchar(MAX) = '
	EXECUTE [FISDataMart].[dbo].[usp_DownloadArc_Codes]
		@TableName = ''' + @TableName + ''',
		@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
'

	IF @IsDebug = 1
	BEGIN
		PRINT @TSQL
	END
	ELSE
		EXEC(@TSQL)
END