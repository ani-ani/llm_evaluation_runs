module parity_checker(input [31:0] data_in, output parity);
assign parity = ^data_in;
endmodule