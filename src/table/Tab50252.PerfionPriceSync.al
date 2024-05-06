table 50252 PerfionPriceSync
{
    DataClassification = ToBeClassified;
    InherentPermissions = rimd;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
        }
        field(5; Processed; Integer)
        {
        }
        field(6; LastSync; DateTime)
        {
        }
        field(7; SalesPriceList; code[20])
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
