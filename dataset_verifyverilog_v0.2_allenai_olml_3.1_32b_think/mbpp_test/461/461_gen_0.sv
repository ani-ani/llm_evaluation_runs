module uppercase_counter (input [7:0][7:0] char_array, input [2:0] valid_length, output [3:0] count);
localparam integer A = 8'h41;
localparam integer Z = 8'h5A;
assign bit0 = (valid_length > 0) && (char_array[0] >= A && char_array[0] <= Z);
assign bit1 = (valid_length > 1) && (char_array[1] >= A && char_array[1] <= Z);
assign bit2 = (valid_length > 2) && (char_array[2] >= A && char_array[2] <= Z);
assign bit3 = (valid_length > 3) && (char_array[3] >= A && char_array[3] <= Z);
assign bit4 = (valid_length > 4) && (char_array[4] >= A && char_array[4] <= Z);
assign bit5 = (valid_length > 5) && (char_array[5] >= A && char_array[5] <= Z);
assign bit6 = (valid_length > 6) && (char_array[6] >= A && char_array[6] <= Z);
assign bit7 = (valid_length > 7) && (char_array[7] >= A && char_array[7] <= Z);
assign count = bit0 + bit1 + bit2 + bit3 + bit4 + bit5 + bit6 + bit7;
endmodule