table 50254 PerfionDataSyncOut
{
    DataClassification = ToBeClassified;
    InherentPermissions = rimd;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
        }
        field(2; Processed; Integer)
        {
        }
        field(3; LastSync; DateTime)
        {
        }
    }
    keys
    {
        key(Key1; "Primary Key")
        {
            Clustered = true;
        }
    }
    fieldgroups
    {
        // Add changes to field groups here
    }
    var
        myInt: Integer;

    trigger OnInsert()
    begin
    end;

    trigger OnModify()
    begin
    end;

    trigger OnDelete()
    begin
    end;

    trigger OnRename()
    begin
    end;
}
