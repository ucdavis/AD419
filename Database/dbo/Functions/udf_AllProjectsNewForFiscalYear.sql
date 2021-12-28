-- =============================================
-- Author:		Ken Taylor
-- Create date: June 29, 2016
-- Description:	Return a list of projects based on the fiscal year provide, including projects that had 
-- expired within the past seven (7) months.
-- Usage:
/*
	USE AD419
	GO

	SELECT * FROM dbo.udf_AllProjectsNewForFiscalYear(2015)
	GO
*/
-- Modifications:
--	2016-07-22 by kjt: Revised to use NewAllProjectsImportV as datasource.
--	2016-08-18 by kjt: Revised to use the AllProjectsNew table.
--  2016-08-19 by kjt: Added Begin and End Data filtering.
--	2016-08-20 by kjt: Added Id and IsIgnored columns.
--	2017-12-12 by kjt: Revised logic to use isExpired as already set during import.
-- =============================================
CREATE FUNCTION [dbo].[udf_AllProjectsNewForFiscalYear] 
(
	@FiscalYear int = 2015
)
RETURNS 
	@AllProjects TABLE 
(	   
	   [AccessionNumber] varchar(7)
      ,[ProjectNumber] varchar(24)
      ,[ProposalNumber] varchar(20)
      ,[AwardNumber] varchar(20)
      ,[Title] varchar(512)
      ,[OrganizationName] varchar(100)
      ,[OrgR] varchar(4)
      ,[Department] varchar(100)
      ,[ProjectDirector] varchar(50)
      ,[CoProjectDirectors] varchar(1024)
      ,[FundingSource] varchar(50)
      ,[ProjectStartDate] datetime2
      ,[ProjectEndDate] datetime2
      ,[ProjectStatus] varchar(50)
      ,[IsUCD] bit
	  ,[IsExpired] bit
	  ,[Is204] bit
	  ,[IsInterdepartmental] bit
	  ,[IsIgnored] bit
	  ,[Id] int
)
AS
BEGIN
	INSERT INTO @AllProjects
	SELECT        
	   [AccessionNumber]
      ,[ProjectNumber]
      ,[ProposalNumber]
      ,[AwardNumber]
      ,[Title]
      ,[OrganizationName]
      ,[OrgR]
      ,[Department]
      ,[ProjectDirector]
      ,[CoProjectDirectors]
      ,[FundingSource]
      ,[ProjectStartDate]
      ,[ProjectEndDate]
      ,[ProjectStatus]
      ,[IsUCD]
      ,[IsExpired]
      ,[Is204]
      ,[IsInterdepartmental]  
	  ,[IsIgnored]
	  ,[Id]           
	FROM	[dbo].[AllProjectsNew] t1
	WHERE
	(t1.ProjectEndDate >= CONVERT(DateTime, CONVERT(varchar(4),@FiscalYear -1) +'-03-01 00:00:00.000')) AND 
    (t1.ProjectStartDate < CONVERT(DateTime, CONVERT(varchar(4),@FiscalYear) + '-10-01 00:00:00.000'))
	RETURN 
END