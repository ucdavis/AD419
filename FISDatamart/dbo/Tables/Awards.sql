CREATE TABLE [dbo].[Awards] (
    [Year]             NUMERIC (4)   NOT NULL,
    [Period]           NVARCHAR (2)  NOT NULL,
    [CgprpslNum]       NUMERIC (12)  NOT NULL,
    [UcLocationCode]   NVARCHAR (2)  NULL,
    [OpFundNum]        NVARCHAR (5)  NULL,
    [LastUpdateDate]   DATETIME2 (7) NULL,
    [CgAwardsStatusCd] VARCHAR (2)   NULL,
    CONSTRAINT [PK_Awards_1] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [CgprpslNum] ASC)
);

