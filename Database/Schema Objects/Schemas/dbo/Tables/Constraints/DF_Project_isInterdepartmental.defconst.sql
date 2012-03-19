ALTER TABLE [dbo].[AllProjects]
    ADD CONSTRAINT [DF_Project_isInterdepartmental] DEFAULT ((0)) FOR [isInterdepartmental];

