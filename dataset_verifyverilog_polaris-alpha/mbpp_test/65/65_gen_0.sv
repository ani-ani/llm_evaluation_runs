module list_sum(
  input  [7:0] elements [7:0],
  input  [7:0] valid_mask,
  output [15:0] total_sum
);

  wire [15:0] masked_elements [7:0];

  assign masked_elements[0] = valid_mask[0] ? {8'b0, elements[0]} : 16'b0;
  assign masked_elements[1] = valid_mask[1] ? {8'b0, elements[1]} : 16'b0;
  assign masked_elements[2] = valid_mask[2] ? {8'b0, elements[2]} : 16'b0;
  assign masked_elements[3] = valid_mask[3] ? {8'b0, elements[3]} : 16'b0;
  assign masked_elements[4] = valid_mask[4] ? {8'b0, elements[4]} : 16'b0;
  assign masked_elements[5] = valid_mask[5] ? {8'b0, elements[5]} : 16'b0;
  assign masked_elements[6] = valid_mask[6] ? {8'b0, elements[6]} : 16'b0;
  assign masked_elements[7] = valid_mask[7] ? {8'b0, elements[7]} : 16'b0;

  // Balanced adder tree for efficiency
  wire [15:0] sum01 = masked_elements[0] + masked_elements[1];
  wire [15:0] sum23 = masked_elements[2] + masked_elements[3];
  wire [15:0] sum45 = masked_elements[4] + masked_elements[5];
  wire [15:0] sum67 = masked_elements[6] + masked_elements[7];

  wire [15:0] sum0123 = sum01 + sum23;
  wire [15:0] sum4567 = sum45 + sum67;

  assign total_sum = sum0123 + sum4567;

endmodule