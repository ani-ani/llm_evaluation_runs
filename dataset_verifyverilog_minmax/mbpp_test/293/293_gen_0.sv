module right_angle_side (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] w,
  input  [7:0] h,
  output reg [15:0] result,
  output reg done
);

  // Fixed-point format for result: Q8.8 (8 integer bits, 8 fractional bits)
  // Iterative non-restoring square root in 16 cycles:
  // - First 8 cycles: compute integer part (9 bits) from the 16-bit radicand (w*w + h*h)
  // - Next  8 cycles: compute 8 fractional bits by shifting in zeros (non-restoring iterations)
  // - Final cycle: round and produce Q8.8 result; assert done for one cycle

  function [17:0] nr_step;
    input [17:0] rem;     // current remainder (signed)
    input [17:0] rad;     // current radicand fragment
    input [8:0]  root;    // current partial root (unsigned, MSB-first)
    begin
      // Non-restoring step for next pair of bits
      // If remainder < 0: root bit = 0; else root bit = 1
      // remainder_next = 2*rem - 2^(n+1)*root_bit - rad
      if (!rem[17]) begin
        // Positive remainder: choose root bit 1
        nr_step = {rem, 2'b00} - {2'b10, rad, 2'b00};
      end else begin
        // Negative remainder: choose root bit 0
        nr_step = {rem, 2'b00} - {2'b00, rad, 2'b00};
      end
    end
  endfunction

  // Internal state
  reg [3:0] state;          // 0=idle, 1..8=int fraction, 9..16=frac, 17=done
  reg [15:0] sum_sq;        // w*w + h*h (unsigned)
  reg [8:0] root;           // partial root (9 bits)
  reg [17:0] rem;           // remainder (signed, needs 1 extra sign bit vs radicand)
  reg [15:0] radicand_reg;  // radicand fragments for integer phase (16 bits)
  reg [3:0] cycle;          // cycle counter 0..7 for integer phase, 0..7 for fraction phase
  reg [1:0] phase;          // 0=idle, 1=integer(8 cycles), 2=fraction(8 cycles), 3=finishing

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 4'd0;
      phase <= 2'd0;
      done  <= 1'b0;
      result <= 16'd0;
      sum_sq <= 16'd0;
      root   <= 9'd0;
      rem    <= 18'd0;
      radicand_reg <= 16'd0;
      cycle  <= 4'd0;
    end else begin
      // Default holds
      done <= 1'b0;
      case (state)
        4'd0: begin // Idle
          if (start) begin
            // Start new calculation
            sum_sq <= w * w + h * h; // 16-bit unsigned sum of squares
            // Pad radicand for 9-bit integer sqrt: use 16 bits + leading '1' gives 17 bits total
            radicand_reg <= {1'b1, sum_sq[15:1]}; // LSB dropped; 17-bit radicand in {1 + 15 MSBs}
            // Initialize non-restoring state
            rem  <= {1'b0, {1'b1, sum_sq[15:1]}}; // remainder = radicand (sign-extend)
            root <= 9'd0;
            phase <= 2'd1; // integer phase
            cycle <= 4'd0;
            state <= 4'd1;
            done  <= 1'b0;
            result <= 16'd0;
          end else begin
            state <= 4'd0;
            done  <= 1'b0;
            result <= 16'd0;
          end
        end

        // Integer phase: 8 cycles to build 9-bit integer sqrt
        4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8: begin
          if (phase == 2'd1) begin
            // Extract current radicand fragment for this 2-bit position
            // Bit-pairs (MSB..LSB): [15:14], [13:12], [11:10], [9:8], [7:6], [5:4], [3:2], [1:0]
            case (cycle)
              4'd0: radicand_reg <= {1'b1, sum_sq[15:1]};
              4'd1: radicand_reg <= {2'b00, sum_sq[15:2]};
              4'd2: radicand_reg <= {2'b00, sum_sq[13:0]};
              4'd3: radicand_reg <= {2'b00, sum_sq[11:0]};
              4'd4: radicand_reg <= {2'b00, sum_sq[9:0]};
              4'd5: radicand_reg <= {2'b00, sum_sq[7:0]};
              4'd6: radicand_reg <= {2'b00, sum_sq[5:0]};
              4'd7: radicand_reg <= {2'b00, sum_sq[3:0]};
              default: radicand_reg <= 16'd0;
            endcase

            // Non-restoring step (2 bits per cycle)
            rem <= nr_step(rem, {1'b0, radicand_reg}, root);
            root[8 - cycle] <= ~rem[17]; // 1 if previous remainder >= 0, else 0
            cycle <= cycle + 1;

            if (cycle == 4'd7) begin
              // Integer phase done: root holds 9-bit integer sqrt
              // Remainder ready for fractional phase
              phase <= 2'd2; // fractional phase
              cycle <= 4'd0;
              state <= 4'd9;
            end else begin
              state <= state + 1;
            end
          end
        end

        // Fraction phase: 8 cycles, each shifts in 2 zeros (non-restoring)
        4'd9, 4'd10, 4'd11, 4'd12, 4'd13, 4'd14, 4'd15, 4'd16: begin
          if (phase == 2'd2) begin
            // Radicand fragment is zero in fractional phase (shift in '00')
            rem <= nr_step(rem, 18'd0, root);
            // Accumulate fractional bits (msb-first, 2 bits per cycle)
            root[7 - cycle] <= ~rem[17]; // first 2 bits go to root[7:6], then [5:4], ...
            cycle <= cycle + 1;

            if (cycle == 4'd7) begin
              // Build Q8.8 result: integer 9 bits -> [8:0], fractional 8 bits -> [7:0]
              // Round: increment fractional if (remainder >= 0)
              // i_part = root[8:0], f_part = {root[7:0], 2'b00}
              // rounding adds 1 in 1/256 if rem >= 0
              if (!rem[17]) begin
                result <= {root[8:0], root[7:0]} + 16'd1;
              end else begin
                result <= {root[8:0], root[7:0]};
              end
              done  <= 1'b1;
              state <= 4'd17; // finishing
            end else begin
              state <= state + 1;
            end
          end
        end

        4'd17: begin
          // Hold result and done for one cycle
          done  <= 1'b0;
          state <= 4'd0;
        end

        default: state <= 4'd0;
      endcase
    end
  end

endmodule
