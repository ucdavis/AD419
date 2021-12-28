

-- =============================================
-- Author:		Ken Taylor
-- Create date: June 14, 2017
-- Description:	Search the PPS Person, Appointments, Distributions function for the appropriate
--   AD-419 reporting year to locate all PIs whom had more that 1 AES OrgR so that we can determine
--     which PIs have interdepartmental projects.
-- Requirements:
--	 The OrgXOrgR table must have been populated, and
--	 The ProjectPI table must have been populated, as well as the ArcCodes and DOSCodes tables. 
-- Usage:
/*
	USE [AD419]
	GO

	SELECT * FROM dbo.udf_GetInterdepartmentalPIsAndOrgs(2017) -- This will use the date range provided.

	-- OR --

	SELECT * FROM dbo.udf_GetInterdepartmentalPIsAndOrgs(DEFAULT, DEFAULT)  -- Use  today's date.

*/
-- Modifications:
-- 2017-07-05 by kjt: Revised to also set IsDepartmental flag
-- 2017-08-10 by kjt: Revised because this is only used by AD-419 and we can just provide a FFY instead of the 2, i.e.
--		begin and end date. 
-- 2017-10-26 by kjt: Added statement to insert any AINT PIs who may not have been picked up because they
--	only have a single AES appointment.  This was true of Mitchell, Jeffery.
-- 2020-04-16 by kjt: Added verbose comments.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetInterdepartmentalPIsAndOrgs] 
(
	-- Add the parameters for the function here
	--@BeginDate datetime2 = null, 
	--@EndDate datetime2 = null
	@FiscalYear int = 2017
)
RETURNS 
@InterdepartmentalPIs TABLE 
(
	EmployeeID varchar(10), 
	FullName varchar(100),
	EmployeeOrgR varchar(4),
	IsInterdepartmental bit
)
AS
BEGIN
	DECLARE @PerAptDis_EmployeeOrgR TABLE (
		EmployeeID varchar(10), 
		FullName varchar(100),
		ProjectOrgR varchar(4), 
		EmployeeOrgR varchar(4),
		IsAESAccount bit,
		OrgRsMatch bit
	)

	DECLARE @BeginDate datetime2 = NULL, @EndDate datetime2 = NULL
	IF @FiscalYear IS NOT NULL
	BEGIN
		SET @BeginDate = CONVERT(datetime2, CONVERT(varchar(4), @FiscalYear-1) + '-10-01')
		SET @EndDate = CONVERT(datetime2, CONVERT(varchar(4), @FiscalYear) + '-09-30')
	END

	/*
		Given a pay end and pay begin date, as in the FFY start and end dates (see above),
		Return a list of employees whom had a job during those dates and were paid between 
			those dates within the appropriate set of DOS codes on AAES accounts.
			
			What we need from udf_PerAptDis is:
			Employee ID,
			Full Name, and
			Chart, Account, ARC, and DOS Code they were paid under during the appropriate period (provided),
			for filtering purposes.  Meaning we only are interested in employee's paid on our sanctioned set of ARC
			and DOS codes.  

			Basically we're adding a single record for each employee/org combination, as the 
			the SELECT DISTINCT will have filtered out employees that have multiple entries 
			for the same org.  
	*/
	INSERT INTO @PerAptDis_EmployeeOrgR
	SELECT DISTINCT 
		   v.[EmployeeID]
		  ,v.[FullName]
		  ,P.OrgR ProjectOrgR
		  ,O.OrgR EmployeeOrgR
		  ,CASE WHEN ArcCode IS NULL THEN 0 ELSE 1 END AS IsAESAccount
		  ,CASE WHEN P.OrgR = O.OrgR THEN 1 ELSE 0 END AS OrgRsMatch
	FROM [PPSDataMart].[dbo].udf_PerAptDis(@BeginDate,@EndDate) v
	INNER JOIN OrgXOrgR O ON v.OrgCode = O.Org
	INNER JOIN FisDataMart.dbo.Accounts A ON 
	v.Chart = A.Chart AND v.Account = A.Account and Year = 9999 and Period = '--'
	INNER JOIN DosCodes ON DOS_CODE = v.DosCode
	INNER JOIN FISDataMart.dbo.ArcCodes C on A.AnnualReportCode = C.ArcCode
	INNER JOIN ProjectPI P ON V.EmployeeID = P.EmployeeID 
	WHERE 
		(O.OrgR != 'ADNO' OR O.OrgR IS NULL)  
		AND (OPFund = '19900' OR left(OPFund,5) BETWEEN '21003' AND '21016')
		AND LEFT(OPFund,5) NOT BETWEEN '21011' AND '21012'
	ORDER BY FullName, ProjectOrgR, EmployeeOrgR

	/*
		Once we have the general list, we add them to the InterdepartmentalPI
		list of employees with more than one record. 
	*/
	INSERT @InterdepartmentalPIs (EmployeeID , FullName, EmployeeOrgR)
	SELECT t1.EmployeeID, t1.FullName, t1.EmployeeOrgR OrgR
	FROM @PerAptDis_EmployeeOrgR t1
	INNER JOIN (
		SELECT [EmployeeID]
		FROM @PerAptDis_EmployeeOrgR
		GROUP BY  
		   [EmployeeID]
		HAVING COUNT(*) > 1
	  ) t2 ON t1.EmployeeID = t2.EmployeeID
	GROUP BY t1.EmployeeID, t1.FullName, t1.EmployeeOrgR
	ORDER BY t1.FullName, t1.EmployeeOrgR, t1.EmployeeID 

	/*
		Add any employees whom might have been left off because they
		only have a single AES appointment, but are housed under AINT.
	*/
	-- 20171026 by kjt: Added statement to insert any AINT PIs who may not have been picked up because they
	--	only have a single AES appointment.  This was true of Mitchell, Jeffery.
	INSERT INTO @InterdepartmentalPIs (EmployeeID , FullName, EmployeeOrgR)
	SELECT t1.EmployeeID, t1.FullName, t1.EmployeeOrgR OrgR
	FROM @PerAptDis_EmployeeOrgR t1
	WHERE ProjectOrgR = 'AINT' AND
	EmployeeID NOT IN (
		SELECT DISTINCT EmployeeID 
		FROM @InterdepartmentalPIs
	) 

	UPDATE @InterdepartmentalPIs
	SET IsInterdepartmental = CASE WHEN t2.OrgCount = 1 THEN 0 ELSE 1 END
	FROM @InterdepartmentalPIs t1
	INNER JOIN (
		SELECT EmployeeID, COUNT(*) OrgCount
		FROM @InterdepartmentalPIs
		GROUP BY EmployeeID
	) t2 ON t1.EmployeeID = t2.EmployeeID
	
	RETURN 
END