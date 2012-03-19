﻿ALTER TABLE [dbo].[Organizations]
    ADD CONSTRAINT [PK_Organizations] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Org] ASC, [Chart] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);
