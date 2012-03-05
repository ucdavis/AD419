ALTER TABLE [dbo].[Trans]
    ADD CONSTRAINT [PK_Trans] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Chart] ASC, [Account] ASC, [SubAccount] ASC, [Object] ASC, [SubObject] ASC, [BalType] ASC, [DocType] ASC, [DocOrigin] ASC, [DocNum] ASC, [LineSquenceNumber] ASC, [PostDate] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

