CREATE UNIQUE INDEX [UX_AllProjects_Source_ProposalNumber]
    ON [data].[AllProjects] ([Source], [ProposalNumber])
    WHERE [ProposalNumber] IS NOT NULL;
