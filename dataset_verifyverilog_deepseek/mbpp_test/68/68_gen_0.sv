module monotonic_checker (
  input [7:0][7:0] array_in,
  input [2:0] actual_elements,
  output reg is_monotonic
);
  wire [6:0] non_dec;
  wire [6:0] non_inc;
  wire [6:0] mask;
  genvar i;
  generate
    for (i = 0; i < 7; i = i + 1) begin : gen_loop
      assign non_dec[i] = (array_in[i] <= array_in[i+1]);
      assign non_inc[i] = (array_in[i] >= array_in[i+1]);
      assign mask[i] = (i < (actual_elements - 1));
    end
  endgenerate
  wire non_decreasing = &(non_dec | ~mask);
  wire non_increasing = &(non_inc | ~mask);
  always @* begin
    is_monotonic = non_decreasing | non_increasing;
  end
endmodule