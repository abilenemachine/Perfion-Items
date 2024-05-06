table 50251 PerfionConfig
{
    DataClassification = ToBeClassified;
    InherentPermissions = rimd;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
        }
        field(2; "Perfion Base URL"; Text[150])
        {
        }
        field(3; "Access Token"; Text[420])
        {
            ExtendedDatatype = Masked;
        }
        field(4; "Enabled"; Boolean)
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
