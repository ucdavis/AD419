﻿ALTER TABLE [dbo].[UserUnit]
    ADD CONSTRAINT [FK_UserUnit_Users] FOREIGN KEY ([UserID]) REFERENCES [dbo].[Users] ([UserID]) ON DELETE NO ACTION ON UPDATE NO ACTION;

