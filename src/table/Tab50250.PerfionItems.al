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
        field(12; "Gen. Prod. Posting Group"; Code[20])
        {
            Caption = 'Condition';
        }
        field(13; Oversize; Decimal)
        {
            Caption = 'Oversize';
            DecimalPlaces = 0 : 5;
        }
        field(14; "Vendor Core"; Decimal)
        {
            Caption = 'Vendor Core';
            Editable = false;
        }
        /* Removed per Lovisa 3/25/24

        Lovisa - that would be fine then if you want to proceed with removing the "VendorCostDate" column from your side.  

        field(15; "Vendor Cost Date"; Date)
        {
            Caption = 'Vendor Cost Date';
            Editable = false;
        }
        */

        /* Removed per Lovisa 5/5/24
        field(14; "Core Resource Name"; Code[20])
        {
            Caption = 'Core Resource Name';
        }
        field(15; "Core Sales Value"; Decimal)
        {
            Caption = 'Core Sales Value';
            DecimalPlaces = 0 : 5;
        }
        */
        field(16; NMFC; Code[30])
        {
            Caption = 'NMFC';
            Editable = false;
        }
        field(17; "Freight Density"; Code[10])
        {
            Caption = 'Freight Density';
            Editable = false;
        }
        field(18; "Minimum Qty"; Decimal)
        {
            Caption = 'Minimum Qty';
            Editable = false;
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
        /*
        field(51; "Vendor Date Changed"; Date)
        {
            Caption = 'Vendor Date Changed';
        }
        */
        field(52; Demand; Decimal)
        {
            Caption = 'Demand';
        }

        /* table 14000584 "LAX DP Surplus Inventory Value" */
        field(55; "Excess Amount"; Decimal)
        {
            Caption = 'Excess Amount';
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