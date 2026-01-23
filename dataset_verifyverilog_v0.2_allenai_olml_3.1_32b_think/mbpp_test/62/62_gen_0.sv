module find_min(input [7:0] data_in [0:7], output [7:0] min_value);
wire [7:0] min0, min1, min2, min3;
wire [7:0] min01, min23;
assign min0 = (data_in[0] < data_in[1]) ? data_in[0] : data_in[1];
assign min1 = (data_in[2] < data_in[3]) ? data_in[2] : data_in[3];
assign min2 = (data_in[4] < data_in[5]) ? data_in[4] : data_in[5];
assign min3 = (data_in[6] < data_in[7]) ? data_in[6] : data_in[7];
assign min01 = (min0 < min1) ? min0 : min1;
assign min23 = (min2 < min3) ? min2 : min3;
assign min_value = (min01 < min23) ? min01 : min23;
endmodule