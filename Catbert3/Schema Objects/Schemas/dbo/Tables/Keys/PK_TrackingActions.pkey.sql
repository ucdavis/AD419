﻿ALTER TABLE [dbo].[TrackingActions]
    ADD CONSTRAINT [PK_TrackingActions] PRIMARY KEY CLUSTERED ([TrackingActionID] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);
