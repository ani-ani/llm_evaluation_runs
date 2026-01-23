module toggle_middle_bits (
    input      [7:0] n,    // 8-bit input number
    output     [7:0] result // 8-bit output with middle bits toggled
);

// Helper to create mask of all 1s from LSB up to highest set bit
// Original logic:
// m |= m >> 1
// m |= m >> 2
// m |= m >> 4
// m |= m >> 8
// m |= m >> 16
// set = (m >> 1) ^ 1

wire [7:0] step1;
assign step1 = n | (n >> 1);

wire [7:0] step2;
assign step2 = step1 | (step1 >> 2);

wire [7:0] step3;
assign step3 = step2 | (step2 >> 4);

// No need for >> 8 and >> 16 for 8-bit input

wire [7:0] set;
assign set = (step3 >> 1) ^ 8'h01;

// Special case: if input is 1, output is 1
// Otherwise: result = n ^ set
wire [7:0] mask;
assign mask = (n == 8'h01) ? 8'h00 : set;

assign result = n ^ mask;

endmodule