



-- =============================================
-- Author:		Ken Taylor
-- Create date: December 16, 2019
-- Description:	Merges the CsTrackingEntryActive table so we can use it for figuring out
-- the AAES, BIOS, and VETM Scientist Years and AAES, BIOS, and VETM Cost Share Scientist Years,
--  since we do not perform a nightly load of the FIS CS_TRACKING_ENTRY_ACTIVE information into
 -- our local FIS DataMart except for when we're ready create a new set of Animal Health Reports.
 --
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_MergeCsTrackingEntryActive]
		@FiscalYear = 2019,
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--  2019-12-16 by kjt: Revised the matching keys to include TrackingEntryTypeCode and 
--	CreateDate.
--	2020=09-22 by kjt: Added distinct to OPENQUERY.
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeCsTrackingEntryActive] 
	@FiscalYear int = 2019, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
MERGE FISDataMart.dbo.CsTrackingEntryActive AS target
USING (SELECT 
	OP_LOCATION_CODE,
	OP_FUND_NUM,
	TRACKING_ENTRY_ID,
	VERSION_NUM,
	TRACKING_ENTRY_TYPE_CODE,
	CHART_NUM,
	ACCT_NUM,
	SUB_ACCT_NUM,
	OBJECT_NUM,
	SUB_OBJECT_NUM,
	PROJECT_NUM,
	REFERENCE_NUM,
	TRACKING_NUM,
	TRACKING_ENTRY_DESC,
	COST_SHARING_PERCENT,
	COST_SHARING_LIMIT_AMOUNT,
	EMPLOYEE_ID,
	START_FISCAL_YEAR,
	END_FISCAL_YEAR,
	START_FISCAL_PERIOD,
	END_FISCAL_PERIOD,
	PAYROLL_PERCENT_TYPE_FLAG,
	CREATE_DATE,
	CREATE_USER_ID,
	LAST_UPDATE_USER_ID,
	LAST_UPDATE_DATE,
	REMOVED_DATE,
	USED_FLAG  
FROM OPENQUERY(FIS_DS,''
SELECT DISTINCT
	OP_LOCATION_CODE,
	OP_FUND_NUM,
	TRACKING_ENTRY_ID,
	VERSION_NUM,
	TRACKING_ENTRY_TYPE_CODE,
	CHART_NUM,
	ACCT_NUM,
	SUB_ACCT_NUM,
	OBJECT_NUM,
	SUB_OBJECT_NUM,
	PROJECT_NUM,
	REFERENCE_NUM,
	TRACKING_NUM,
	TRACKING_ENTRY_DESC,
	COST_SHARING_PERCENT,
	COST_SHARING_LIMIT_AMOUNT,
	EMPLOYEE_ID,
	START_FISCAL_YEAR,
	END_FISCAL_YEAR,
	START_FISCAL_PERIOD,
	END_FISCAL_PERIOD,
	PAYROLL_PERCENT_TYPE_FLAG,
	CREATE_DATE,
	CREATE_USER_ID,
	LAST_UPDATE_USER_ID,
	LAST_UPDATE_DATE,
	REMOVED_DATE,
	USED_FLAG 
FROM
	FINANCE.CS_TRACKING_ENTRY_ACTIVE
'')
) AS source ON (
	target.TrackingEntryId = source.TRACKING_ENTRY_ID AND 
	target.VersionNum = source.VERSION_NUM AND
	target.TrackingEntryTypeCode = source.TRACKING_ENTRY_TYPE_CODE AND
	target.CreateDate = source.CREATE_DATE
	)
WHEN MATCHED THEN UPDATE SET
	 [OpLocationCode] 		=	OP_LOCATION_CODE
	,[OpFundNum]			=	OP_FUND_NUM
	--,[TrackingEntryTypeCode]=	TRACKING_ENTRY_TYPE_CODE
	,[Chart]				=	CHART_NUM
	,[Account]				=	ACCT_NUM
	,[SubAccount]			=	SUB_ACCT_NUM
	,[Object]				=	OBJECT_NUM
	,[SubObject]			=	SUB_OBJECT_NUM
	,[Project]				=	PROJECT_NUM
	,[ReferenceNum]			=	REFERENCE_NUM
	,[TrackingNum]			=	TRACKING_NUM
	,[TrackingEntryDesc]	=	TRACKING_ENTRY_DESC
	,[CostSharingPercent]	=	COST_SHARING_PERCENT
	,[CostSharingLimitAmount]=	COST_SHARING_LIMIT_AMOUNT
	,[EmployeeId]			=	EMPLOYEE_ID
	,[StartFiscalYear]		=	START_FISCAL_YEAR
	,[EndFiscalYear]		=	END_FISCAL_YEAR
	,[StartFiscalPeriod]	=	START_FISCAL_PERIOD
	,[EndFiscalPeriod]		=	END_FISCAL_PERIOD
	,[PayrollPercentTypeFlag]=	PAYROLL_PERCENT_TYPE_FLAG
	--,[CreateDate]			=	CREATE_DATE
	,[CreateUserId]			=	CREATE_USER_ID
	,[LastUpdateUserId]		=	LAST_UPDATE_USER_ID
	,[LastUpdateDate]		=	LAST_UPDATE_DATE
	,[RemovedFlag]			=	REMOVED_DATE
	,[UsedFlag]				=	USED_FLAG 
	,[IsActive]				= 1

WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	OP_LOCATION_CODE,
	OP_FUND_NUM,
	TRACKING_ENTRY_ID,
	VERSION_NUM,
	TRACKING_ENTRY_TYPE_CODE,
	CHART_NUM,
	ACCT_NUM,
	SUB_ACCT_NUM,
	OBJECT_NUM,
	SUB_OBJECT_NUM,
	PROJECT_NUM,
	REFERENCE_NUM,
	TRACKING_NUM,
	TRACKING_ENTRY_DESC,
	COST_SHARING_PERCENT,
	COST_SHARING_LIMIT_AMOUNT,
	EMPLOYEE_ID,
	START_FISCAL_YEAR,
	END_FISCAL_YEAR,
	START_FISCAL_PERIOD,
	END_FISCAL_PERIOD,
	PAYROLL_PERCENT_TYPE_FLAG,
	CREATE_DATE,
	CREATE_USER_ID,
	LAST_UPDATE_USER_ID,
	LAST_UPDATE_DATE,
	REMOVED_DATE,
	USED_FLAG,
	1
 )
WHEN NOT MATCHED BY SOURCE THEN UPDATE
SET IsActive = 0
;
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END