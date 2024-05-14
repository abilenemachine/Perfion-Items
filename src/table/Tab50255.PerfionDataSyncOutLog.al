table 50255 PerfionDataSyncOutLog
{
    DataClassification = CustomerContent;
    InherentPermissions = rimd;

    fields
    {
        field(1; "Item No."; Code[20])
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
    }
    keys
    {
        key(Key1; "Item No.")
        {
            Clustered = true;
        }
        key(key2; "Last Updated")
        {

        }
    }
    fieldgroups
    {
        // Add changes to field groups here
    }
}
