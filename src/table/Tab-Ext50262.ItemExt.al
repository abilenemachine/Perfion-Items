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

    }
}
