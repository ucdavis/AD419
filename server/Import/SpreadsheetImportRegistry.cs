namespace Server.Import;

public interface ISpreadsheetImportRegistry
{
    IReadOnlyList<ImportDatasetDefinition> Datasets { get; }
    ImportDatasetDefinition? Find(string datasetId);
}

public sealed class SpreadsheetImportRegistry : ISpreadsheetImportRegistry
{
    private static readonly IReadOnlyList<ImportDatasetDefinition> DatasetDefinitions =
    [
        new(
            "all-projects",
            "All Projects",
            "data",
            "AllProjects",
            [
                Text("AccessionNumber", true, 50, "Accession Number"),
                Text("ProjectNumber", false, 20, "Project Number"),
                Text("ProposalNumber", false, 10, "Proposal Number"),
                Text("AwardNumber", false, 16, "Award Number"),
                Text("Title", false, null, "Project Title"),
                Text("OrganizationName", true, 300, "Organization Name"),
                Text("Department", false, 300),
                Text("ProjectDirector", true, 200, "Project Director"),
                Text("ProjectDirectorEmail", false, 320, "Project Director Email", "PD Email"),
                Text("Aor", false, 200, "AOR"),
                Text("AorEmail", false, 320, "AOR Email"),
                Text("FundingSource", true, 100, "Funding Source"),
                Flag("IsThisAnAreeraSection204IntegratedActivity", false, "Is This An AREERA Section 204 Integrated Activity", "204 Integrated Activity", "Is 204"),
                Text("Program", false, 100),
                Text("ProgramName", false, 300, "Program Name"),
                Number("ActivitiesResearch", false, "Activities Research"),
                Number("ActivitiesExtension", false, "Activities Extension"),
                Number("ActivitiesEducation", false, "Activities Education"),
                Date("ProjectStartDate", false, "Project Start Date", "Start Date"),
                Date("ProjectEndDate", false, "Project End Date", "End Date"),
                SmallInt("LastProgressReportFy", false, "Last Progress Report FY"),
                Text("ReportingPeriodOfPerformance", false, 50, "Reporting Period Of Performance"),
                Text("ProjectFinancialReportFiscalYear", false, 50, "Project Financial Report Fiscal Year"),
                Date("FinalReportSubmissionDate", false, "Final Report Submission Date"),
                Text("DocumentType", true, 7, "Document Type"),
                Text("ProgressReportStatus", false, 50, "Progress Report Status"),
                Text("ProjectStatus", true, 100, "Project Status"),
                Text("ProjectFinancialReportStatus", false, 50, "Project Financial Report Status"),
                Text("Source", true, 3),
            ],
            [
                new("Accession Number", ["AccessionNumber"]),
                new("Project Number", ["ProjectNumber"]),
                new("Source and Proposal Number", ["Source", "ProposalNumber"]),
            ]),
        new(
            "active-projects",
            "Active Projects",
            "data",
            "ActiveProjects",
            [
                Text("ProjectNumber", true, 20, "Project Number"),
                Text("AccessionNumber", true, 7, "Accession Number"),
                Text("UcpEmployeeId", true, 8, "UCP Employee ID", "UCPath Employee ID"),
                Text("UcPathName", true, 200, "UCPath Name"),
                Flag("Is204", true, "Is 204", "204"),
                Flag("ExcludeFromUi", false, "Exclude From UI"),
                Text("Notes", false, null),
                Text("ProjectDirector", true, 200, "Project Director"),
                Text("PdEmailAddress", true, 320, "PD Email Address", "Project Director Email"),
            ],
            [
                new("Accession Number", ["AccessionNumber"]),
                new("Project Number", ["ProjectNumber"]),
            ]),
        new(
            "assistance-listing-numbers",
            "Assistance Listing Numbers",
            "data",
            "AssistanceListingNumbers",
            [
                Text("ProgramTitle", true, 500, "Program Title", "Assistance Listing Title", "Title"),
                Text("ProgramNumber", true, 6, "Program Number", "Assistance Listing Number", "ALN", "CFDA Number"),
                Text("PopularName020", false, 500, "Popular Name 020", "020 Popular Name", "Popular Name"),
                Text("FederalAgency030", true, 500, "Federal Agency 030", "030 Federal Agency", "Federal Agency"),
                Text("Authorization040", true, null, "Authorization 040", "040 Authorization"),
                Text("Objectives050", true, null, "Objectives 050", "050 Objectives"),
                Text("TypesOfAssistance060", true, null, "Types Of Assistance 060", "060 Types Of Assistance"),
                Text("UsesAndUseRestrictions070", true, 50, "Uses And Use Restrictions 070", "070 Uses And Use Restrictions"),
                Text("ApplicantEligibility081", true, null, "Applicant Eligibility 081", "081 Applicant Eligibility"),
                Text("BeneficiaryEligibility082", true, null, "Beneficiary Eligibility 082", "082 Beneficiary Eligibility"),
                Text("CredentialsDocumentation083", true, null, "Credentials Documentation 083", "083 Credentials Documentation"),
                Text("PreapplicationCoordination091", true, null, "Preapplication Coordination 091", "091 Preapplication Coordination"),
                Text("ApplicationProcedures092", true, null, "Application Procedures 092", "092 Application Procedures"),
                Text("AwardProcedure093", true, null, "Award Procedure 093", "093 Award Procedure"),
                Text("Deadlines094", true, null, "Deadlines 094", "094 Deadlines"),
                Text("RangeOfApprovalDisapprovalTime095", true, null, "Range Of Approval Disapproval Time 095", "095 Range Of Approval Disapproval Time"),
                Text("Appeals096", true, null, "Appeals 096", "096 Appeals"),
                Text("Renewals097", true, null, "Renewals 097", "097 Renewals"),
                Text("FormulaAndMatchingRequirements101", true, null, "Formula And Matching Requirements 101", "101 Formula And Matching Requirements"),
                Text("LengthAndTimePhasingOfAssistance102", true, null, "Length And Time Phasing Of Assistance 102", "102 Length And Time Phasing Of Assistance"),
                Text("Reports111", true, null, "Reports 111", "111 Reports"),
                Text("Audits112", true, null, "Audits 112", "112 Audits"),
                Text("Records113", false, null, "Records 113", "113 Records"),
                Text("AccountIdentification121", true, null, "Account Identification 121", "121 Account Identification"),
                Text("Obligations122", true, null, "Obligations 122", "122 Obligations"),
                Text("RangeAndAverageOfFinancialAssistance123", false, null, "Range And Average Of Financial Assistance 123", "123 Range And Average Of Financial Assistance"),
                Text("ProgramAccomplishments130", true, null, "Program Accomplishments 130", "130 Program Accomplishments"),
                Text("RegulationsGuidelinesAndLiterature140", true, null, "Regulations Guidelines And Literature 140", "140 Regulations Guidelines And Literature"),
                Text("RegionalOrLocalOffice151", true, null, "Regional Or Local Office 151", "151 Regional Or Local Office"),
                Text("HeadquartersOffice152", true, null, "Headquarters Office 152", "152 Headquarters Office"),
                Text("WebsiteAddress153", false, 2000, "Website Address 153", "153 Website Address"),
                Text("RelatedPrograms160", false, null, "Related Programs 160", "160 Related Programs"),
                Text("ExamplesOfFundedProjects170", false, null, "Examples Of Funded Projects 170", "170 Examples Of Funded Projects"),
                Text("CriteriaForSelectingProposals180", true, null, "Criteria For Selecting Proposals 180", "180 Criteria For Selecting Proposals"),
                Date("PublishedDate", true, "Published Date"),
                Text("ParentShortname", false, 100, "Parent Shortname", "Parent Short Name"),
                Text("Url", true, 2000, "URL"),
                Flag("Recovery", true),
            ],
            [
                new("Program Number", ["ProgramNumber"]),
            ]),
    ];

    public IReadOnlyList<ImportDatasetDefinition> Datasets => DatasetDefinitions;

    public ImportDatasetDefinition? Find(string datasetId)
    {
        return Datasets.SingleOrDefault(dataset =>
            string.Equals(dataset.Id, datasetId, StringComparison.OrdinalIgnoreCase));
    }

    private static ImportColumn Text(string targetColumn, bool required, int? maxLength, params string[] sourceHeaders)
    {
        return new ImportColumn(targetColumn, ImportColumnType.String, required, maxLength, sourceHeaders);
    }

    private static ImportColumn Flag(string targetColumn, bool required, params string[] sourceHeaders)
    {
        return new ImportColumn(targetColumn, ImportColumnType.Boolean, required, null, sourceHeaders);
    }

    private static ImportColumn Number(string targetColumn, bool required, params string[] sourceHeaders)
    {
        return new ImportColumn(targetColumn, ImportColumnType.Decimal, required, null, sourceHeaders);
    }

    private static ImportColumn Date(string targetColumn, bool required, params string[] sourceHeaders)
    {
        return new ImportColumn(targetColumn, ImportColumnType.Date, required, null, sourceHeaders);
    }

    private static ImportColumn SmallInt(string targetColumn, bool required, params string[] sourceHeaders)
    {
        return new ImportColumn(targetColumn, ImportColumnType.Int16, required, null, sourceHeaders);
    }
}
