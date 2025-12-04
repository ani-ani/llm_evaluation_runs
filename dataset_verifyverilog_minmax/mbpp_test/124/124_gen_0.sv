module complex_angle (
  input clk,
  input rst_n,
  input start,
  input [31:0] real_part,
  input [31:0] imag_part,
  output reg [31:0] angle,
  output reg done
);

  // Q16.16 constants
  localparam PI_Q16_16 = 32'h00010000 * 3; // 0x00030000
  localparam PI_NEG_Q16_16 = 32'h00010000 * (-3);

  // CORDIC iterations: 16 cycles
  localparam ITER_W = 4;
  localparam MAX_ITER = 16;

  reg [31:0] x, y, z;
  reg [31:0] x_next, y_next, z_next;
  reg [31:0] real_reg, imag_reg;
  reg [ITER_W-1:0] iter_cnt;
  reg run_q, run_d;

  // Quadrant correction
  wire [1:0] quad;
  assign quad = {imag_reg[31], real_reg[31]}; // 2'b00=Q1, 2'b01=Q4, 2'b11=Q2, 2'b10=Q3

  // CORDIC atan table for 16 iterations (Q16.16 radians)
  // atan(2^-i) in Q16.16: * 2^16 / (2*pi) => 0x00010000 = 1 radian
  always @(*) begin
    case (iter_cnt)
       0: z_next = 32'h00010000 * 45;          // 45 deg
       1: z_next = 32'h00010000 * 26;          // atan2^-1 ~ 26.565 deg
       2: z_next = 32'h00010000 * 14;          // ~14.036 deg
       3: z_next = 32'h00010000 * 7;           // ~7.125 deg
       4: z_next = 32'h00010000 * 3;           // ~3.576 deg
       5: z_next = 32'h00010000 * 1;           // ~1.789 deg
       6: z_next = 32'h00010000 * 0;           // ~0.895 deg
       7: z_next = 32'h00010000 * 0;           // ~0.448 deg
       8: z_next = 32'h00010000 * 0;           // ~0.224 deg
       9: z_next = 32'h00010000 * 0;           // ~0.112 deg
      10: z_next = 32'h00010000 * 0;           // ~0.056 deg
      11: z_next = 32'h00010000 * 0;           // ~0.028 deg
      12: z_next = 32'h00010000 * 0;           // ~0.014 deg
      13: z_next = 32'h00010000 * 0;           // ~0.007 deg
      14: z_next = 32'h00010000 * 0;           // ~0.003 deg
      15: z_next = 32'h00010000 * 0;           // ~0.002 deg
    endcase
  end

  // Control: latch inputs and start CORDIC
  always @(*) begin
    if (!run_q) begin
      if (start) begin
        // Capture inputs at start pulse
        x_next = real_reg;
        y_next = imag_reg;
        // Initialize z with quadrant correction
        case (quad)
          2'b00: z_next = 32'h0;            // Q1
          2'b01: z_next = 32'h0;            // Q4
          2'b11: z_next = PI_Q16_16;        // Q2
          2'b10: z_next = PI_NEG_Q16_16;    // Q3
        endcase
        run_d = 1'b1;
      end else begin
        x_next = x;
        y_next = y;
        z_next = z;
        run_d = run_q;
      end
    end else begin
      // CORDIC rotation iteration
      run_d = 1'b1;
      if (y[31] == 1'b0) begin // y >= 0
        x_next = x + (y >>> iter_cnt);
        y_next = y - (x >>> iter_cnt);
        z_next = z + z_next; // subtract arctan if y < 0 else add
      end else begin // y < 0
        x_next = x - (y >>> iter_cnt);
        y_next = y + (x >>> iter_cnt);
        z_next = z - z_next;
      end
    end
  end

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      angle <= 32'h0;
      done <= 1'b0;
      x <= 32'h0;
      y <= 32'h0;
      z <= 32'h0;
      real_reg <= 32'h0;
      imag_reg <= 32'h0;
      iter_cnt <= 4'd0;
      run_q <= 1'b0;
    end else begin
      // Inputs (latched on start)
      if (start) begin
        real_reg <= real_part;
        imag_reg <= imag_part;
      end

      // Register next values
      x <= x_next;
      y <= y_next;
      z <= z_next;
      run_q <= run_d;

      // Iteration counter
      if (!run_q) begin
        if (start) iter_cnt <= 4'd0;
        else       iter_cnt <= iter_cnt;
      end else if (run_q) begin
        if (iter_cnt == (MAX_ITER-1)) iter_cnt <= 4'd0;
        else                          iter_cnt <= iter_cnt + 1'b1;
      end

      // Done pulse and output angle
      if (run_q && (iter_cnt == (MAX_ITER-1))) begin
        angle <= z_next;
        done  <= 1'b1;
      end else begin
        angle <= angle; // hold
        done  <= 1'b0;
      end
    end
  end

endmodule
