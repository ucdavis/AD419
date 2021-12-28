


CREATE VIEW [dbo].[AD419CurrentProjectListV]
AS
/*
    Author: Ken Taylor
    Created: 2018-11-05
    Description: Returns a proposed list of projects that we will be reporting on
        based on the following criteria:
        1. The project start date is less than the reporting period end date.
`       2. The project end date is greater than the reporting period begin date, i.e., 2017-10-01.  Note greater than as opposed to grater than or
            -- equal to because some end dated are entered as 10-01-(yyyy-1) when they really should have been entered 09-30-(yyyy-1), and 
            -- and these projects we getting picked up in the current list when they should have been excluded.
        3. The project is UCD, i.e., SAES - UNIVERSITY OF CALIFORNIA AT DAVIS.
        4. The project is not expired, i.e., the end date is greater then the beginning of the current reporting period.
        5. A valid accession number has been assigned, i.e., is not like '0000000'.
        6. The project status is one of those we consider to be viable, i.e., Completed, Completed without Final Report, Active, etc.
            -- This list is maintained in the data helper, and resides in the ProjectStatus table.
     Note that the FiscalYear is selected from the dbo.CurrentFiscalYear table.
     Usage:

     USE [AD419]
     GO

     SELECT * FROM [dbo].[AD419CurrentProjectListV]
     
    GO

    Modifications:
    2018-11-05 by kjt: Added comments section, revised ProjectEndDate filter to be greater than (yyyy-1)-10-01 to filter out
        ProjectEndDates that were entered incorrectly, i.e. 10-01-yyyy instead of 09-30-yyyy.
*/

SELECT
	ProjectNew.Id,
	ProjectNew.AccessionNumber,
	ProjectNew.ProjectNumber,
	ProjectNew.ProposalNumber,
	ProjectNew.AwardNumber,
	ProjectNew.Title,
	ProjectNew.OrganizationName,
	ProjectNew.OrgR,
	ProjectNew.Department,
	ProjectNew.ProjectDirector,
	ProjectNew.CoProjectDirectors,
	ProjectNew.FundingSource,
	ProjectNew.ProjectStartDate,
	ProjectNew.ProjectEndDate,
	ProjectNew.ProjectStatus,
	ProjectNew.IsInterdepartmental,
	ProjectNew.Is204,
	CONVERT(BIT, ISNULL(ProjectNew.IsIgnored ^ 1, 1)) AS IsAssociable 
FROM
	dbo.AllProjectsNew AS ProjectNew 
INNER JOIN dbo.CurrentFiscalYear AS t2 ON 
    ProjectNew.ProjectEndDate > CONVERT(DateTime, CONVERT(VARCHAR(4), t2.FiscalYear - 1) + '-10-01 00:00:00.000') AND
    ProjectNew.ProjectStartDate < CONVERT(DateTime, CONVERT(VARCHAR(4), t2.FiscalYear) + '-10-01 00:00:00.000') 
LEFT OUTER JOIN dbo.ReportingOrg AS t8 ON 
    ProjectNew.OrgR = t8.OrgR AND
	(t8.IsActive = 1 OR t8.OrgR IN ('XXXX', 'AINT')) 
WHERE
	(ProjectNew.IsUCD = 1) AND
	(ProjectNew.IsExpired = 0) AND
	(ProjectNew.AccessionNumber NOT LIKE '0000000') AND
	(
        RTRIM(ProjectNew.ProjectStatus) NOT IN 
        (	SELECT
                Status 
            FROM
                dbo.ProjectStatus 
            WHERE
                IsExcluded = 1
        )
    )
GO



GO


