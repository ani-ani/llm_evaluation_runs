module tuple_search (
  input [79:0] data_array,
  input [7:0] target,
  input [3:0] valid_count,
  output found
);

  wire [9:0] match;
  genvar i;

  generate
    for (i = 0; i < 10; i = i + 1) begin : compare_loop
      assign match[i] = (i < valid_count) ? (data_array[(i+1)*8-1 : i*8] == target) : 1'b0;
    end
  endgenerate

  assign found = |match[9:0];

endmodule