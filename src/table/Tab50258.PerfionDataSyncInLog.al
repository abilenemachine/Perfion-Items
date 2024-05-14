table 50258 PerfionDataSyncInLog
{
    DataClassification = CustomerContent;
    InherentPermissions = rimd;

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Editable = true;
        }
        field(2; "Original Value"; Text[100])
        {
            Editable = true;
        }
        field(3; "Updated Value"; Text[100])
        {
            Editable = true;
        }
        field(4; "Value Type"; Enum PerfionValueType)
        {
            Editable = true;
        }

        field(10; "Last Modified"; DateTime)
        {
            Editable = true;
        }
        field(11; "Last Updated"; DateTime)
        {
            Editable = true;
        }
        field(12; "Magento Sync"; Text[20])
        {
            Editable = true;
        }
    }
    keys
    {
        key(Key1; "Item No.", "Value Type", "Last Updated")
        {
            Clustered = true;
        }
        key(Key2; "Item No.")
        {

        }
    }
    fieldgroups
    {
        // Add changes to field groups here
    }
}
