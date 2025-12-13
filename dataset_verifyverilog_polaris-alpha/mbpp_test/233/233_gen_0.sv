module cylinder_lateral_area(
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] radius,
  input  [15:0] height,
  output reg [63:0] result,
  output reg        done
);

  // Precomputed 2*pi in Q16.16: 6.2830 -> 0x0006_487E
  localparam [31:0] TWO_PI_Q16_16 = 32'h0006_487E;

  // Stage 1 pipeline register: 2*pi * radius (Q16.16 * Q16.16 = Q32.32 in 64 bits)
  reg [63:0] mul1_res;

  // Stage control registers
  reg start_d1;
  reg start_d2;

  // Stage 1: multiply 2*pi by radius
  // Stage 2: multiply intermediate result by height, keep upper 64 bits

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul1_res  <= 64'd0;
      result    <= 64'd0;
      done      <= 1'b0;
      start_d1  <= 1'b0;
      start_d2  <= 1'b0;
    end else begin
      // Pipeline start signal
      start_d1 <= start;
      start_d2 <= start_d1;

      // Stage 1: 2*pi * radius
      // Inputs radius (16b) and TWO_PI_Q16_16 (32b) -> 48b product,
      // assign into 64b for alignment and simplicity.
      if (start) begin
        mul1_res <= TWO_PI_Q16_16 * radius;
      end

      // Stage 2: (mul1_res * height), select upper 64 bits as Q16.16 result
      if (start_d1) begin
        result <= (mul1_res * height) [127:64];
      end

      // done asserted in cycle 2 after start
      done <= start_d2;
    end
  end

endmodule