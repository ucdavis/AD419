﻿ALTER TABLE [dbo].[Departments]
    ADD CONSTRAINT [PK_Departments] PRIMARY KEY CLUSTERED ([HomeDeptNo] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

