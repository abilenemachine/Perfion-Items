table 50250 PerfionItems
{
    Caption = 'Perfion Items';
    DataCaptionFields = "No.", Description;

    fields
    {
        /* Item Card */
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description 2';
        }
        field(3; GTIN; Code[14])
        {
            Caption = 'GTIN';
            Numeric = true;
        }
        field(4; Blocked; Boolean)
        {
            Caption = 'Blocked';
        }
        field(5; "Replenishment System"; Enum "Replenishment System")
        {
            Caption = 'Replenishment System';
        }
        field(6; "Inventory Posting Group"; Code[20])
        {
            Caption = 'Inventory Posting Group';
        }
        field(7; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
        }
        field(8; "Item Category Code"; Code[20])
        {
            Caption = 'Item Category Code';
        }
        field(9; "Drop Ship"; Boolean)
        {
            Caption = 'Drop shipable';
        }
        field(10; "Unit Cost"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Unit Cost';
            MinValue = 0;
        }
        field(11; "Vendor Cost"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Vendor Cost';
            MinValue = 0;
        }
        field(15; "Last Date Modified"; Date)
        {
            Caption = 'Last Date Modified';
            Editable = false;
        }
        field(16; "Last DateTime Modified"; DateTime)
        {
            Caption = 'Last DateTime Modified';
        }
        /* table 5404 "Item Unit of Measure" */
        field(20; Length; Decimal)
        {
            Caption = 'Length';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(21; Width; Decimal)
        {
            Caption = 'Width';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(22; Height; Decimal)
        {
            Caption = 'Height';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(23; Cubage; Decimal)
        {
            Caption = 'Cubage';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(24; Weight; Decimal)
        {
            Caption = 'Weight';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }

        /* table 14000555 "LAX DP Procurement Unit" */
        field(50; "Item Class Description"; Text[30])
        {
            Caption = 'Item Class Description';
        }
        field(51; "Procurement Date Changed"; Date)
        {
            Caption = 'Procurement Date Changed';
        }

        /* table 5777 "Item Reference" */
        field(60; "Reference No."; Code[50])
        {
            Caption = 'Reference No.';
        }

        field(70; "Quantity KS"; Decimal)
        {
            Caption = 'Quantity Kansas';
            DecimalPlaces = 0 : 5;
        }
        field(71; "Quantity SC"; Decimal)
        {
            Caption = 'Quantity South Carolina';
            DecimalPlaces = 0 : 5;
        }
        field(72; "Quantity SD"; Decimal)
        {
            Caption = 'Quantity South Dakota';
            DecimalPlaces = 0 : 5;
        }
        field(73; "Quantity MT"; Decimal)
        {
            Caption = 'Quantity Montana';
            DecimalPlaces = 0 : 5;
        }

        field(100; Id; Integer)
        {
            AutoIncrement = true;
        }

    }
    keys
    {
        key(PrimaryKey; "No.")
        {
            Clustered = TRUE;
        }
        key(key1; Id)
        {

        }
    }
}