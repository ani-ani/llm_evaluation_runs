module check_unique (
    input [7:0] data_0,
    input [7:0] data_1,
    input [7:0] data_2,
    input [7:0] data_3,
    input [7:0] data_4,
    input [7:0] data_5,
    input [7:0] data_6,
    input [7:0] data_7,
    output unique
);

    wire eq_01, eq_02, eq_03, eq_04, eq_05, eq_06, eq_07;
    wire eq_12, eq_13, eq_14, eq_15, eq_16, eq_17;
    wire eq_23, eq_24, eq_25, eq_26, eq_27;
    wire eq_34, eq_35, eq_36, eq_37;
    wire eq_45, eq_46, eq_47;
    wire eq_56, eq_57;
    wire eq_67;

    assign eq_01 = (data_0 == data_1);
    assign eq_02 = (data_0 == data_2);
    assign eq_03 = (data_0 == data_3);
    assign eq_04 = (data_0 == data_4);
    assign eq_05 = (data_0 == data_5);
    assign eq_06 = (data_0 == data_6);
    assign eq_07 = (data_0 == data_7);

    assign eq_12 = (data_1 == data_2);
    assign eq_13 = (data_1 == data_3);
    assign eq_14 = (data_1 == data_4);
    assign eq_15 = (data_1 == data_5);
    assign eq_16 = (data_1 == data_6);
    assign eq_17 = (data_1 == data_7);

    assign eq_23 = (data_2 == data_3);
    assign eq_24 = (data_2 == data_4);
    assign eq_25 = (data_2 == data_5);
    assign eq_26 = (data_2 == data_6);
    assign eq_27 = (data_2 == data_7);

    assign eq_34 = (data_3 == data_4);
    assign eq_35 = (data_3 == data_5);
    assign eq_36 = (data_3 == data_6);
    assign eq_37 = (data_3 == data_7);

    assign eq_45 = (data_4 == data_5);
    assign eq_46 = (data_4 == data_6);
    assign eq_47 = (data_4 == data_7);

    assign eq_56 = (data_5 == data_6);
    assign eq_57 = (data_5 == data_7);

    assign eq_67 = (data_6 == data_7);

    assign unique = ~(eq_01 | eq_02 | eq_03 | eq_04 | eq_05 | eq_06 | eq_07 |
                      eq_12 | eq_13 | eq_14 | eq_15 | eq_16 | eq_17 |
                      eq_23 | eq_24 | eq_25 | eq_26 | eq_27 |
                      eq_34 | eq_35 | eq_36 | eq_37 |
                      eq_45 | eq_46 | eq_47 |
                      eq_56 | eq_57 |
                      eq_67);

endmodule