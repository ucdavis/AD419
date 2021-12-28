CREATE TABLE [dbo].[Schools] (
    [SchoolCode]       VARCHAR (10)  NOT NULL,
    [ShortDescription] VARCHAR (50)  NULL,
    [LongDescription]  VARCHAR (200) NULL,
    [Abbreviation]     VARCHAR (12)  NULL,
    CONSTRAINT [PK_Schools] PRIMARY KEY CLUSTERED ([SchoolCode] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Contains the School to SchoolCode translations.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Schools';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Short school/division name: The short description of the school or division code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Schools', @level2type = N'COLUMN', @level2name = N'ShortDescription';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'School/Division code: The unique 2-digit UCD-created code that indicates the school/division to which the work home department belongs. If the work or alternate home department was blank, the primary home department was used to calculate the school/division. (translation in Schools table)  (Primary key)', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Schools', @level2type = N'COLUMN', @level2name = N'SchoolCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Full school/division name: The complete description of the school or division code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Schools', @level2type = N'COLUMN', @level2name = N'LongDescription';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Abbreviated School/Division name: The abbreviated description of the school or division code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Schools', @level2type = N'COLUMN', @level2name = N'Abbreviation';

