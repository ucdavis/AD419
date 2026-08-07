CREATE NONCLUSTERED INDEX [IX_PGMProjects_SponsorAwardKey]
    ON [data].[PGMProjects] ([SponsorAwardKey])
    INCLUDE ([ProjectNumber], [SponsorAwardNumber], [CfdaProgramNumber]);
