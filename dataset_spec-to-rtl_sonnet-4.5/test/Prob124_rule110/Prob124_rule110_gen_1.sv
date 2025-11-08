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
    for (i = 0; i < 512; i = i + 1) begin : rule110_cell
      wire left, center, right;
      
      // Determine neighbors with boundary conditions
      assign center = q[i];
      assign left = (i == 511) ? 1'b0 : q[i+1];
      assign right = (i == 0) ? 1'b0 : q[i-1];
      
      // Rule 110 truth table
      // LCR: 111->0, 110->1, 101->1, 100->0, 011->1, 010->1, 001->1, 000->0
      // This simplifies to: (L&C&~R) | (L&~C&R) | (~L&C&R) | (~L&C&~R) | (~L&~C&R)
      // Which further simplifies to: (C&~R) | (~L&C) | (~L&R) | (L&~C&R)
      // Or more efficiently: ~(~C&~R) & ~(L&C&R) = (C|R) & ~(L&C&R)
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