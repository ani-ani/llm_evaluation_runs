module complex_to_polar (
  input clk,
  input rst_n,
  input start,
  input [31:0] real_part,
  input [31:0] imag_part,
  output reg [31:0] magnitude,
  output reg [31:0] phase,
  output reg done
);
  // Internal registers
  reg [1:0] state;
  reg [6:0] iter_cnt;     // 0..31 for 32 micro-iterations (2 per cycle)
  reg start_latch;

  // CORDIC working registers (Q32.32 for pipeline precision, then downcast to Q16.16 outputs)
  // We use 48-bit signed to hold 16.16 inputs and intermediate growth from shifts.
  logic signed [47:0] x, y;
  // Angle accumulator uses 64-bit to avoid overflow on additions and range adjustments
  logic signed [63:0] z;

  // Next pipeline values (two micro-iterations per clock)
  logic signed [47:0] x_next, y_next;
  logic signed [63:0] z_next;

  // Shift indices for two micro-iterations
  integer sh1, sh2;

  // CORDIC gain K in Q16.16 (approx 0.607252935)
  // Note: In Q16.16, this equals floor(0.607252935 * 2^16 + 0.5) = 39798 = 16'h9B76
  // 16'h9B76 is 0x9B76; using 32-bit width to avoid sign-extension issues
  logic [31:0] K_Q16_16 = 32'h00009B76;

  // State machine
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE = 2'b10;

  // Compute micro-iterations (two at a time to fit 32 cycles total, 2 micro-iterations per cycle = 16 cycles)
  // But we still allow 0..31 iterations to meet "up to 32 clock cycles" wording.
  // 2 micro-iterations per cycle -> 16 cycles; 1 micro-iteration per cycle -> 32 cycles (when unrolled is kept simple).
  // Unroll two micro-iterations per clock for efficiency.
  always_comb begin
    // Default next values (keep unchanged if not in compute)
    x_next = x;
    y_next = y;
    z_next = z;
    sh1 = 0;
    sh2 = 0;
    if (state == COMPUTE) begin
      sh1 = iter_cnt;
      sh2 = (iter_cnt < 31) ? (iter_cnt + 1) : 31;

      // First micro-iteration
      if (y < 0) begin
        // y was positive -> add angle, subtract y-scaled from x, add x-scaled to y
        x_next = x + (y >>> sh1);
        y_next = y - (x >>> sh1);
        z_next = z + (64'sh4000 >>> sh1); // 0.25*pi in Q32.32
      end else begin
        // y <= 0 -> subtract angle, add y-scaled to x, subtract x-scaled from y
        x_next = x - (y >>> sh1);
        y_next = y + (x >>> sh1);
        z_next = z - (64'sh4000 >>> sh1);
      end

      // Second micro-iteration
      if (y_next < 0) begin
        x_next = x_next + (y_next >>> sh2);
        y_next = y_next - (x_next >>> sh2);
        z_next = z_next + (64'sh4000 >>> sh2);
      end else begin
        x_next = x_next - (y_next >>> sh2);
        y_next = y_next + (x_next >>> sh2);
        z_next = z_next - (64'sh4000 >>> sh2);
      end
    end
  end

  // Stage 1: Scale and normalize to Q16.16, with saturation and sign handling
  function [31:0] scale_mag_and_normalize;
    input signed [47:0] x_in; // Q16.16 input -> 48-bit (16.16), but register was 16.16 scaled to 32.16, so cast to 47:16 for fraction
    // We'll convert Q16.16 fixed-point represented in 48-bit: high 16 = int, low 16 = frac
    // But x is still Q16.16 kept in 48-bit; to cast to Q16.16 result, take upper 32 bits
    // However to keep design simple: x already holds Q16.16 (no extra shift). We'll use upper 32 bits.
    // x_in is 48-bit, representing Q16.16; we need upper 16 bits for integer and lower 16 for fraction.
    // So we can directly take {x_in[47:16], x_in[15:0]?} -> but that is 48 bits. Instead, reinterpret as 32-bit by dropping LSBs.
    // Since our pipeline used 48-bit to avoid overflow, the true Q16.16 value sits in the top 32 bits of the 48-bit.
    // Therefore, we simply return x_in[47:16] (rounded/truncated).
    // For rounding, add 1 if LSB is 1.
    logic [31:0] mag16_16;
    logic round;
    begin
      mag16_16 = x_in[47:16];
      round = x_in[15]; // Q16.16 lsb
      if (round) mag16_16 = mag16_16 + 1;
      // Saturate negative overflow to 0x80000000 -> 0x7FFFFFFF
      if (mag16_16[31] == 1'b1) begin
        // Negative magnitude (shouldn't happen with CORDIC), clamp to zero
        mag16_16 = 32'h00000000;
      end
      // Clamp to max positive
      if (mag16_16 > 32'h7FFFFFFF) mag16_16 = 32'h7FFFFFFF;
      scale_mag_and_normalize = mag16_16;
    end
  endfunction

  // Stage 2: Normalize angle to Q16.16 in range [-pi, pi] using mapping and sat
  function [31:0] norm_angle_q16_16;
    input signed [63:0] z_full; // Full precision angle accumulator (Q32.32 ideally)
    // Convert to Q16.16 by rounding/truncating low 16 bits
    logic [31:0] z16_16;
    logic [15:0] frac;
    logic round;
    logic signed [63:0] z_adj;
    begin
      // Round to nearest in Q16.16
      z_adj = z_full + (z_full[15] ? (1 << 15) : -(1 << 15)); // Add +/- 0.5 in Q16.16 => +/- 0.5*2^16 = 2^15
      z16_16 = z_adj[47:16]; // Truncate to 32-bit
      // Normalize to [-pi, pi] by subtracting sign(z)*2*pi as needed
      // 2*pi in Q16.16 is 2*3.141592653589793 = 6.283185307179586 = 0x0006487F
      // We'll iteratively subtract or add 2*pi until the value is within [-pi, pi]
      // pi Q16.16 is 0x0003243F; 2*pi is 0x0006487E (approx)
      while (z16_16 > 32'h0003243F) z16_16 = z16_16 - 32'h0006487E;
      while (z16_16 < 32'hFFFDCB81) z16_16 = z16_16 + 32'h0006487E; // -pi is -0x0003243F -> 32-bit signed is 0xFFFDCB81
      norm_angle_q16_16 = z16_16;
    end
  endfunction

  // FSM + datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      iter_cnt <= 7'h0;
      start_latch <= 1'b0;
      x <= 48'h0;
      y <= 48'h0;
      z <= 64'h0;
      magnitude <= 32'h0;
      phase <= 32'h0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Latch inputs as Q16.16 in a 48-bit container
            x <= {imag_part, 16'h0}; // Keep low 16 fractional bits as 0 for scaling convenience; note: we use x for magnitude pipeline; real_part is used in first micro-iter (x = real_part)
            y <= 48'h0;
            z <= 64'h0;
            // Initialize CORDIC with (x0, y0) = (real, imag)
            // Because the pipeline registers are named x,y but start as imaginary part for CORDIC; we need to use real and imag directly.
            // Re-override: Set x0 = real, y0 = imag using a corrected assignment below (first micro-iteration expects them accordingly).
            // For clarity, we will set them again below.
            // Correct initialization for CORDIC vectoring mode:
            x <= {real_part, 16'h0}; // Q16.16 -> placed in high 16 bits of 48-bit, low 16 = 0
            y <= {imag_part, 16'h0};
            z <= 64'h0;
            iter_cnt <= 7'h0;
            start_latch <= 1'b1;
            done <= 1'b0;
            state <= COMPUTE;
          end else begin
            // Hold outputs
            done <= 1'b0;
            start_latch <= 1'b0;
          end
        end

        COMPUTE: begin
          // Update pipeline
          x <= x_next;
          y <= y_next;
          z <= z_next;

          // End condition: we've executed 32 micro-iterations (2 per cycle => 16 cycles)
          if (iter_cnt >= 31) begin
            // Scale and normalize on last cycle
            magnitude <= scale_mag_and_normalize(x_next);
            phase <= norm_angle_q16_16(z_next);
            state <= DONE;
            done <= 1'b1;
            start_latch <= 1'b0;
          end else begin
            // Prepare next two micro-iterations
            iter_cnt <= iter_cnt + 2;
          end
        end

        DONE: begin
          // Hold outputs until next start
          if (start) begin
            // Restart immediately
            x <= {real_part, 16'h0};
            y <= {imag_part, 16'h0};
            z <= 64'h0;
            iter_cnt <= 7'h0;
            state <= COMPUTE;
            done <= 1'b0; // will be re-asserted after compute
          end else begin
            done <= 1'b1;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
