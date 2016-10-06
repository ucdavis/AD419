CREATE TABLE [dbo].[AllProjectsNew] (
    [Id]                  INT            IDENTITY (1, 1) NOT NULL,
    [AccessionNumber]     VARCHAR (7)    NULL,
    [ProjectNumber]       VARCHAR (24)   NULL,
    [ProposalNumber]      VARCHAR (20)   NULL,
    [AwardNumber]         VARCHAR (20)   NULL,
    [Title]               VARCHAR (512)  NULL,
    [OrganizationName]    VARCHAR (100)  NULL,
    [OrgR]                VARCHAR (4)    NULL,
    [Department]          VARCHAR (100)  NULL,
    [ProjectDirector]     VARCHAR (50)   NULL,
    [CoProjectDirectors]  VARCHAR (1024) NULL,
    [FundingSource]       VARCHAR (50)   NULL,
    [ProjectStartDate]    DATETIME2 (7)  NULL,
    [ProjectEndDate]      DATETIME2 (7)  NULL,
    [ProjectStatus]       VARCHAR (50)   NULL,
    [IsUCD]               BIT            NULL,
    [IsExpired]           BIT            NULL,
    [Is204]               BIT            NULL,
    [IsInterdepartmental] BIT            NULL,
    [IsIgnored]           BIT            NULL,
    CONSTRAINT [PK_AllProjectsNew_1] PRIMARY KEY CLUSTERED ([Id] ASC)
);

