module rear_extract(input [2:0] num_tuples, input [7:0] tuple_field0 [0:3], input [7:0] tuple_field1 [0:3], input [7:0] tuple_field2 [0:3], output reg [7:0] rear_elements [0:3]);
assign rear_elements[0] = (num_tuples >= 1) ? tuple_field2[0] : 8'h00;
assign rear_elements[1] = (num_tuples >= 2) ? tuple_field2[1] : 8'h00;
assign rear_elements[2] = (num_tuples >= 3) ? tuple_field2[2] : 8'h00;
assign rear_elements[3] = (num_tuples >= 4) ? tuple_field2[3] : 8'h00;
endmodule