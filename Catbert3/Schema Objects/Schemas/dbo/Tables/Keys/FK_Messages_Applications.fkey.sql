ALTER TABLE [dbo].[Messages]
    ADD CONSTRAINT [FK_Messages_Applications] FOREIGN KEY ([ApplicationID]) REFERENCES [dbo].[Applications] ([ApplicationID]) ON DELETE NO ACTION ON UPDATE NO ACTION;

