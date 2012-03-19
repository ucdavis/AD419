ALTER TABLE [dbo].[AllProjects]
    ADD CONSTRAINT [DF_Project_isValid] DEFAULT ((1)) FOR [isValid];

