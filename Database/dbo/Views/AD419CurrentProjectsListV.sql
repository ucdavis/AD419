



CREATE VIEW [dbo].[AD419CurrentProjectsListV]
AS
/*
    Author: Ken Taylor
    Created: October 27, 2020
    Description: Returns a proposed list of projects that we will be reporting on
		bsed on 
        
     Note that the FiscalYear is selected from the dbo.CurrentFiscalYear table, and
		the [dbo].[NifaProjectAccessionNumberImport] must have been loaded.

     Usage:

     USE [AD419]
     GO

     SELECT * FROM [dbo].[AD419CurrentProjectsListV]
     
    GO

    Modifications:
		2020-10-27 Replaces the [dbo].[AD419CurrentProjectListV], as that view 
			filtered out some project present in the NifaProjectAccessionNumberImport
			table.
*/

	SELECT TOP (1000)
	   NifaProjects.AccessionNumber AS NifaAccessionNumber
	  ,NifaProjects.ProjectNumber AS NifaProjectNumber
	  ,ProjectNew.AccessionNumber AS AnrAccessionNumber
	  ,ProjectNew.ProjectNumber AS AnrProjectNumber
	  ,ProjectNew.ProposalNumber
	  ,ProjectNew.AwardNumber
	  ,ProjectNew.Title
	  ,ProjectNew.OrganizationName
	  ,ProjectNew.OrgR
	  ,ProjectNew.Department
	  ,ProjectNew.ProjectDirector
	  ,ProjectNew.CoProjectDirectors
	  ,ProjectNew.FundingSource
	  ,ProjectNew.ProjectStartDate
	  ,ProjectNew.ProjectEndDate
	  ,ProjectNew.ProjectStatus
	  ,CASE WHEN ProjectNew.AccessionNumber IS NULL THEN 1 
			ELSE 0 
		END AS IsMissingFromAnrProjects 
	  ,CASE WHEN ProjectNew.IsUCD = 0 THEN 0 
			WHEN ProjectNew.IsUCD IS NULL THEN NULL 
			ELSE 1 
		END AS IsUCD
	   ,CASE WHEN ProjectNew.IsExpired = 1 THEN 1 
			WHEN ProjectNew.IsExpired IS NULL THEN NULL 
			ELSE 0 
		END AS IsExpired
	   ,CASE WHEN ProjectNew.ProjectEndDate > CONVERT(DateTime, CONVERT(VARCHAR(4), t2.FiscalYear - 1) + '-10-01 00:00:00.000') AND
			ProjectNew.ProjectStartDate < CONVERT(DateTime, CONVERT(VARCHAR(4), t2.FiscalYear) + '-10-01 00:00:00.000') THEN 1
			WHEN ProjectNew.ProjectEndDate IS NULL OR ProjectNew.ProjectStartDate IS NULL THEN NULL
			ELSE 0 
		END AS IsValidDate
	   ,CASE WHEN (
			RTRIM(ProjectNew.ProjectStatus) NOT IN 
			(	SELECT
					Status 
				FROM
					dbo.ProjectStatus 
				WHERE
					IsExcluded = 1
			)
			) THEN 1
			WHEN RTRIM(ProjectNew.ProjectStatus) IS NULL THEN NULL
			ELSE 0  
		END AS IsValidStatus
	  ,CASE WHEN ProjectNew.IsInterdepartmental = 1 THEN 1 
			WHEN ProjectNew.IsInterdepartmental IS NULL THEN NULL
			ELSE 0
		END AS IsInterdepartmental
	  ,CASE WHEN ProjectNew.AccessionNumber IS NOT NULL AND CONVERT(BIT, ISNULL(ProjectNew.IsIgnored ^ 1, 1)) = 1 THEN 1
			WHEN ProjectNew.IsIgnored IS NULL THEN NULL
			ELSE 0 
		END AS IsAssociable 
	  FROM [dbo].[NifaProjectAccessionNumberImport] NifaProjects
	  CROSS JOIN [dbo].[CurrentFiscalYear] t2
	  LEFT OUTER JOIN [dbo].[AllProjectsNew] ProjectNew ON NifaProjects.AccessionNumber = ProjectNew.AccessionNumber
	  LEFT OUTER JOIN dbo.ReportingOrg AS t8 ON 
		ProjectNew.OrgR = t8.OrgR AND
		(t8.IsActive = 1 OR t8.OrgR IN ('XXXX', 'AINT')) 
	ORDER BY IsMissingFromAnrProjects DESC, IsValidStatus, IsValidDate, NifaAccessionNumber