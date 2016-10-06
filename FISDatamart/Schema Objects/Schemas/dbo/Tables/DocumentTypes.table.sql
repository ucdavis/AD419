CREATE TABLE [dbo].[DocumentTypes] (
    [DocumentType]                      VARCHAR (4)  NOT NULL,
    [DocumentTypeName]                  VARCHAR (40) NULL,
    [DocumentGroupCode]                 VARCHAR (2)  NULL,
    [DocumentGroupName]                 VARCHAR (40) NULL,
    [DocumentSubsystemCode]             VARCHAR (2)  NULL,
    [DocumentActiveIndicator]           VARCHAR (1)  NULL,
    [ChartManagerRoutingIndicator]      VARCHAR (1)  NULL,
    [AccountManagerRoutingIndicator]    VARCHAR (1)  NULL,
    [ReviewHierarchyRoutingIndicator]   VARCHAR (1)  NULL,
    [SpecialConditionsRoutingIndicator] VARCHAR (1)  NULL,
    [LastUpdateDate]                    DATETIME     NULL,
    CONSTRAINT [PK_DocumentTypes] PRIMARY KEY CLUSTERED ([DocumentType] ASC)
);




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Document Type: This table names the document types used in the DaFIS transaction processing environment.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'FIS Document Type Number:  Identifies a Financial Information System (FIS) document type (i.e. Expense transfer, budget adjustment, journal vouchers, purchase requisitions, purchase orders, etc.).', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'DocumentType';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'FIS Document Type Name: Descriptive name given to a document type number.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'DocumentTypeName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Document Type Group Code: Identifies the group of document types within an FIS subsystem that the Document is acssociated with. E.G. Financial Documents, Reference Table Maintenance, Purchasing Documents, Accounts Receivable Maintenance, AP Documents. ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'DocumentGroupCode';




GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'FIS Document Type Group Name: Descriptive name given to a document group code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'DocumentGroupName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'FIS Document Type Subsystem Code: dentifies the FIS subsystem that the Document is associated with. E.G. AP, AR, CM, TP.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'DocumentSubsystemCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'FIS Document Type Active Indicator: Indicates whether this document is active and available for use in the TP environment.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'DocumentActiveIndicator';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Chart Manager Routing Indicator: Indicates if this document routes to the Chart Manager by default', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'ChartManagerRoutingIndicator';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Account Manager Routing Indicator: Indicates if this document routes to the Account Manager by default', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'AccountManagerRoutingIndicator';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Review Hierarchy Routing Indicator: Indicates if the routing of this document can be changed by the review hierarchy.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'ReviewHierarchyRoutingIndicator';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Special Conditions Routing Indicator: Indicates if the routing of this document can be changed by special conditions routing.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'SpecialConditionsRoutingIndicator';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: Indicates if the routing of this document can be changed by special conditions routing.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentTypes', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

