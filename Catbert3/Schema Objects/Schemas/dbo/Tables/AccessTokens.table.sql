CREATE TABLE [dbo].[AccessTokens] (
    [ID]            INT           IDENTITY (1, 1) NOT NULL,
    [Token]         CHAR (32)     NOT NULL,
    [ApplicationID] INT           NOT NULL,
    [ContactEmail]  VARCHAR (50)  NOT NULL,
    [Reason]        VARCHAR (MAX) NULL,
    [Active]        BIT           NOT NULL
);




GO
CREATE UNIQUE CLUSTERED INDEX [ClusteredIndex-20161103-115611]
    ON [dbo].[AccessTokens]([Token] ASC, [ApplicationID] ASC);

