﻿ALTER TABLE [dbo].[UserUnit]
    ADD CONSTRAINT [PK_UserUnit] PRIMARY KEY CLUSTERED ([UserID] ASC, [UnitID] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

