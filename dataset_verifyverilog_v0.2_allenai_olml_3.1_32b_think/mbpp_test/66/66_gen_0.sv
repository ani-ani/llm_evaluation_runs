module pos_counter (input [7:0] data_in_0, input [7:0] data_in_1, input [7:0] data_in_2, input [7:0] data_in_3, output [2:0] count);
assign count = (!data_in_0[7] + !data_in_1[7] + !data_in_2[7] + !data_in_3[7]);
endmodule