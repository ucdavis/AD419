﻿ALTER TABLE [dbo].[ARC_Codes]
    ADD CONSTRAINT [DF_ARC_Codes_isAES] DEFAULT ((0)) FOR [isAES];
