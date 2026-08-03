CREATE NONCLUSTERED INDEX [IX_AllProjects_ProjectAccessionNormalized_Cycle]
    ON [data].[AllProjects] ([ProjectNumberNormalized], [AccessionNumberNormalized], [ProjectEndDate], [ProjectStartDate])
    INCLUDE ([AllProjectId], [AwardNumber], [AwardKey], [Department], [ProjectDirector]);
