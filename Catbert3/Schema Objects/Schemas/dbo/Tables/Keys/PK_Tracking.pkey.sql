﻿ALTER TABLE [dbo].[Tracking]
    ADD CONSTRAINT [PK_Tracking] PRIMARY KEY CLUSTERED ([TrackingID] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);
