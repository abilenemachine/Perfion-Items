table 50261 PerfionDataReconcileLog
{
    DataClassification = CustomerContent;
    InherentPermissions = rimd;

    fields
    {
        field(1; "Code"; Code[20])
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
        field(5; "Change Type"; Enum PerfionReconcileType)
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
        key(Key1; "Code", "Last Updated")
        {
            Clustered = true;
        }
    }
    fieldgroups
    {
        // Add changes to field groups here
    }
}
