CREATE NONCLUSTERED INDEX [IX_AllProjects_ProjectAccession_Cycle]
    ON [data].[AllProjects] ([ProjectNumber], [AccessionNumber], [ProjectEndDate], [ProjectStartDate])
    INCLUDE ([AllProjectId], [AwardNumber], [AwardKey], [Department], [ProjectDirector]);
