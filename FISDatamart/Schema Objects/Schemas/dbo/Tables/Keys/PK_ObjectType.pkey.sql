﻿ALTER TABLE [dbo].[ObjectTypes]
    ADD CONSTRAINT [PK_ObjectType] PRIMARY KEY CLUSTERED ([ObjectType] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

