module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);

  wire [511:0] next_q;

  // Rule 110 logic for each cell
  genvar i;
  generate
    for (i = 0; i < 512; i = i + 1) begin : rule110
      wire left, center, right;
      
      // Determine neighbors with boundary conditions
      assign center = q[i];
      assign left = (i == 511) ? 1'b0 : q[i+1];
      assign right = (i == 0) ? 1'b0 : q[i-1];
      
      // Rule 110 lookup table
      // Left | Center | Right | Next
      //  1   |   1    |   1   |  0
      //  1   |   1    |   0   |  1
      //  1   |   0    |   1   |  1
      //  1   |   0    |   0   |  0
      //  0   |   1    |   1   |  1
      //  0   |   1    |   0   |  1
      //  0   |   0    |   1   |  1
      //  0   |   0    |   0   |  0
      assign next_q[i] = (left & center & ~right) |
                         (left & ~center & right) |
                         (~left & center & right) |
                         (~left & center & ~right) |
                         (~left & ~center & right);
    end
  endgenerate

  // Sequential logic
  always @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end

endmodule