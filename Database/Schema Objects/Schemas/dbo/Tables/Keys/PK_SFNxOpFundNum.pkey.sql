﻿ALTER TABLE [dbo].[SFNxOpFundNum]
    ADD CONSTRAINT [PK_SFNxOpFundNum] PRIMARY KEY CLUSTERED ([SFN] ASC, [OpFundNum] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

