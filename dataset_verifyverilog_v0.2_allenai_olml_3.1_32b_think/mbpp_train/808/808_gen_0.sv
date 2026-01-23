module tuple_contains_k(input [7:0] k, input [7:0] data [0:7], output found);
assign found = (data[0] == k) || (data[1] == k) || (data[2] == k) || (data[3] == k) || (data[4] == k) || (data[5] == k) || (data[6] == k) || (data[7] == k);
endmodule