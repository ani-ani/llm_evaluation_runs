module pairwise_consecutive(
  input [7:0][7:0] data_in,
  input [2:0] num_elements,
  output reg [6:0][15:0] pairs_out,
  output reg [2:0] num_pairs
);

  integer i;
  always @* begin
    num_pairs = (num_elements > 1) ? (num_elements - 1) : 0;
    for (i = 0; i < 7; i = i + 1) begin
      if (i < num_pairs) begin
        pairs_out[i] = {data_in[i], data_in[i+1]};
      end else begin
        pairs_out[i] = 16'b0;
      end
    end
  end

endmodule