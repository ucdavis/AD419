﻿ALTER TABLE [dbo].[TitleGroups]
    ADD CONSTRAINT [PK_TitleGroups] PRIMARY KEY CLUSTERED ([JobGroupID] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

