﻿ALTER TABLE [dbo].[DocumentOriginCodes]
    ADD CONSTRAINT [PK_DocumentOriginCodes] PRIMARY KEY CLUSTERED ([DocumentOriginCode] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

