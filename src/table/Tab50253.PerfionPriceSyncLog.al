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
        field(5; "UOM"; Code[10])
        {
            Editable = true;
        }
        field(10; "Last Modified"; Text[20])
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
        key(Key1; "Item No.", "Price Group", "Last Updated")
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
