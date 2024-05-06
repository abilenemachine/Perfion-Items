table 50253 PerfionPriceSyncLog
{
    DataClassification = CustomerContent;
    InherentPermissions = rimd;

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Editable = true;
        }
        field(2; "Original Price"; Decimal)
        {
            Editable = true;
        }
        field(3; "Updated Price"; Decimal)
        {
            Editable = true;
        }
        field(4; "Price Group"; Code[20])
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
        key(Key1; "Item No.", "Price Group")
        {
            Clustered = true;
        }
    }
    fieldgroups
    {
        // Add changes to field groups here
    }
}
