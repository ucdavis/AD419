﻿ALTER TABLE [dbo].[EmploymentStatusCodes]
    ADD CONSTRAINT [PK_EmployeeStatusCodes] PRIMARY KEY CLUSTERED ([Code] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

