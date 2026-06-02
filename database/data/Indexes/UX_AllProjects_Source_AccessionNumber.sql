CREATE UNIQUE INDEX [UX_AllProjects_Source_AccessionNumber]
    ON [data].[AllProjects] ([Source], [AccessionNumber])
    WHERE [AccessionNumber] IS NOT NULL;
