table 50259 MagentoLog
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; ID; Integer)
        {
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(2; "Key"; Text[200])
        {
            DataClassification = CustomerContent;
        }
        field(4; "Date/Time"; DateTime)
        {
            DataClassification = CustomerContent;
        }
        field(5; "Process"; Enum MagentoProcess)
        {
            DataClassification = CustomerContent;
        }
        field(6; "Error Message"; Text[500])
        {
            DataClassification = CustomerContent;
        }
        field(8; "Item No"; Code[20])
        {
            DataClassification = CustomerContent;
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
        Rec."Date/Time" := CurrentDateTime;
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
