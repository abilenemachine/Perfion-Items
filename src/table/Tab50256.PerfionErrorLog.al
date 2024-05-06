table 50256 PerfionErrorLog
{
    DataClassification = CustomerContent;
    InherentPermissions = rimd;

    fields
    {
        field(1; "ID"; Integer)
        {
            AutoIncrement = true;
        }
        field(2; "Date/Time"; DateTime)
        {
        }
        field(3; "Item No."; Code[20])
        {
        }
        field(4; "Process"; Text[50])
        {
        }
        field(5; "Error Message"; Text[250])
        {
        }
    }
    keys
    {
        key(Key1; ID)
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
