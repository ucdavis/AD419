/*
Post-deployment hook for the data DACPAC.

Keep this script limited to small reference data required by schema constraints.
*/

MERGE [data].[Sfns] AS target
USING
(
    VALUES
        (N'201', N'Hatch Funds'),
        (N'202', N'Multi-State Research Funds'),
        (N'203', N'McIntire-Stennis Funds'),
        (N'204', N'Contracts, Grants, Research Coop Agreements'),
        (N'205', N'OtherFunds(AnimalHealthSec1433,Evans-Allen)'),
        (N'209', N'National Science Foundation'),
        (N'219', N'USDA Contracts, Grants, Coop Agreements'),
        (N'220', N'State Appropriations'),
        (N'221', N'Self-Generated Funds'),
        (N'222', N'Industry Grants and Agreements'),
        (N'223', N'Other Non-Federal Funds')
) AS source ([Sfn], [Label])
    ON target.[Sfn] = source.[Sfn]
WHEN MATCHED AND target.[Label] <> source.[Label] THEN
    UPDATE SET [Label] = source.[Label]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([Sfn], [Label])
    VALUES (source.[Sfn], source.[Label]);

-- ADNO must exist because [data].[v_TransactionOrgR] forces title code 1010
-- rows to it. All other OrgRs are loaded once per environment outside source
-- control and maintained in-app.
MERGE [data].[OrgRs] AS target
USING (VALUES (N'ADNO')) AS source ([Code])
    ON target.[Code] = source.[Code]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([Code])
    VALUES (source.[Code]);
