module check_unique (
    input [7:0] data_0, data_1, data_2, data_3, data_4, data_5, data_6, data_7,
    output unique
);
assign unique = ~ (
    (data_0 == data_1) || (data_0 == data_2) || (data_0 == data_3) || (data_0 == data_4) || 
    (data_0 == data_5) || (data_0 == data_6) || (data_0 == data_7) || 
    (data_1 == data_2) || (data_1 == data_3) || (data_1 == data_4) || (data_1 == data_5) || 
    (data_1 == data_6) || (data_1 == data_7) || 
    (data_2 == data_3) || (data_2 == data_4) || (data_2 == data_5) || (data_2 == data_6) || 
    (data_2 == data_7) || 
    (data_3 == data_4) || (data_3 == data_5) || (data_3 == data_6) || (data_3 == data_7) || 
    (data_4 == data_5) || (data_4 == data_6) || (data_4 == data_7) || 
    (data_5 == data_6) || (data_5 == data_7) || 
    (data_6 == data_7)
);
endmodule