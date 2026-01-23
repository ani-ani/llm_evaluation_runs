module tuple_search (
    input [79:0] data_array,
    input [7:0] target,
    input [3:0] valid_count,
    output found
);

// Extract each byte from data_array
assign byte0 = data_array[7:0];
assign byte1 = data_array[15:8];
assign byte2 = data_array[23:16];
assign byte3 = data_array[31:24];
assign byte4 = data_array[39:32];
assign byte5 = data_array[47:40];
assign byte6 = data_array[55:48];
assign byte7 = data_array[63:56];
assign byte8 = data_array[71:64];
assign byte9 = data_array[79:72];

// Compare each byte to target
assign match0 = byte0 == target;
assign match1 = byte1 == target;
assign match2 = byte2 == target;
assign match3 = byte3 == target;
assign match4 = byte4 == target;
assign match5 = byte5 == target;
assign match6 = byte6 == target;
assign match7 = byte7 == target;
assign match8 = byte8 == target;
assign match9 = byte9 == target;

// Generate enable signals based on valid_count
assign enable0 = valid_count > 0;
assign enable1 = valid_count > 1;
assign enable2 = valid_count > 2;
assign enable3 = valid_count > 3;
assign enable4 = valid_count > 4;
assign enable5 = valid_count > 5;
assign enable6 = valid_count > 6;
assign enable7 = valid_count > 7;
assign enable8 = valid_count > 8;
assign enable9 = valid_count > 9;

// Combine matches with enables and OR results
assign found0 = match0 & enable0;
assign found1 = match1 & enable1;
assign found2 = match2 & enable2;
assign found3 = match3 & enable3;
assign found4 = match4 & enable4;
assign found5 = match5 & enable5;
assign found6 = match6 & enable6;
assign found7 = match7 & enable7;
assign found8 = match8 & enable8;
assign found9 = match9 & enable9;

assign found = found0 | found1 | found2 | found3 | found4 | found5 | found6 | found7 | found8 | found9;

endmodule