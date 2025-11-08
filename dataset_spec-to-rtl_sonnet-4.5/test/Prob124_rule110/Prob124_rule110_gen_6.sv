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
      // Which further simplifies to: (C&~R) | (~L&R) | (L&C&~R) = ~R&(C|L) | ~L&R = ~(L^R) & (C|R)
      // Or more directly from the table: R | (C & ~L) | (L & C & ~R) - let me recalculate
      // Rule 110: outputs 1 for cases 110, 101, 011, 010, 001 (binary positions)
      // = (L&C&~R) | (L&~C&R) | (~L&C&R) | (~L&C&~R) | (~L&~C&R)
      // = C&~R | ~L&R | L&C&~R = (C&~R) | (~L&R) 
      // Let me verify: (C&~R)|(~L&R) = (~R&C)|(~L&R) = R&~L | C&~R
      // Checking: 110->1: 1&~1|0&~0 = 0|0 = 0 WRONG
      // Direct from table: output = R | (C&~(L&R))
      // Let me implement directly:
      assign next_q[i] = (left & center & ~right) ? 1'b0 :
                         (left & center & right) ? 1'b0 :
                         (left & ~center & ~right) ? 1'b0 :
                         (~left & ~center & ~right) ? 1'b0 : 1'b1;
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