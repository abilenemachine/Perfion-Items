tableextension 50262 ItemPerfion extends Item
{
    fields
    {
        field(50262; MagentoVisibility; Enum PerfionMagentoVisibilityType)
        {
            Caption = 'Magento Visibility';
            FieldClass = Normal;
            Editable = false;
        }

        field(50263; PerfionSync; Enum PerfionSyncStatus)
        {
            Caption = 'Perfion Sync Status';
            FieldClass = Normal;
            Editable = true;
            InitValue = "For Review"; // sets the default
        }

        field(50264; PerfionPicture; Enum PerfionPictureStatus)
        {
            Caption = 'Perfion Picture Status';
            FieldClass = Normal;
            Editable = true;
            InitValue = "Unassigned"; // sets the default
        }
        field(50265; SlsMgrEnrichStatus; Enum PerfionSlsMgrEnrichStatus)
        {
            Caption = 'Sales Manager Enrichment Status';
            FieldClass = Normal;
            Editable = false;
        }
        field(50266; PerfionUserNotes; Text[2048])
        {
            Caption = 'Perfion User Notes';
            FieldClass = Normal;
            Editable = false;
        }
        field(50267; PerfionCreatedOn; DateTime)
        {
            Caption = 'Perfion Created On';
            FieldClass = Normal;
            Editable = false;
        }

    }
}
