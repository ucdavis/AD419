﻿ALTER TABLE [dbo].[Projects]
    ADD CONSTRAINT [PK_Projects] PRIMARY KEY CLUSTERED ([Year] ASC, [Period] ASC, [Number] ASC, [Chart] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);

