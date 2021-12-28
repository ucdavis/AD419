CREATE TABLE [dbo].[Schools_PPS] (
    [SchoolCode]       VARCHAR (10)  NOT NULL,
    [ShortDescription] VARCHAR (50)  NULL,
    [LongDescription]  VARCHAR (200) NULL,
    [Abbreviation]     VARCHAR (12)  NULL,
    CONSTRAINT [PK_Schools_PPS] PRIMARY KEY CLUSTERED ([SchoolCode] ASC)
);

