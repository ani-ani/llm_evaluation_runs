module mean_abs_dev (
  input clk,
  input rst_n,
  input start,
  input [31:0] num0,
  input [31:0] num1,
  input [31:0] num2,
  input [31:0] num3,
  output reg [31:0] mad,
  output reg done
);

  // Internal pipeline registers (Q16.16)
  reg [31:0] r0, r1, r2, r3;
  reg [47:0] sum_s48;      // 48-bit accumulator for sum(xi) (Q16.16)
  reg [31:0] mean;         // Q16.16 mean of four inputs
  reg [47:0] sum_abs;      // 48-bit accumulator for sum(|xi-mean|) (Q16.16)
  reg [31:0] result;       // Q16.16 final MAD before output register

  // State machine
  localparam S_IDLE  = 3'b000;
  localparam S_C1    = 3'b001;  // Cycle 1: latch inputs
  localparam S_C2    = 3'b010;  // Cycle 2: compute mean
  localparam S_C3    = 3'b011;  // Cycle 3: |x0-mean|
  localparam S_C4    = 3'b100;  // Cycle 4: |x1-mean|
  localparam S_C5    = 3'b101;  // Cycle 5: |x2-mean|
  localparam S_C6    = 3'b110;  // Cycle 6: |x3-mean|
  localparam S_C7    = 3'b111;  // Cycle 7: average abs diffs (divide by 4)
  reg [2:0] state, next;

  // Utility: 48-bit signed saturation to [-2^47, 2^47-1]
  function [47:0] sat48;
    input signed [47:0] x;
    begin
      sat48 = (x > $signed(48'h7FFF_FFFF_FFFF)) ? 48'h7FFF_FFFF_FFFF
               : (x < $signed(48'h8000_0000_0000)) ? 48'h8000_0000_0000
               : x;
    end
  endfunction

  // 48-bit signed add with saturation
  function [47:0] add48;
    input signed [47:0] a, b;
    add48 = sat48(a + b);
  endfunction

  // 48-bit signed subtract with saturation
  function [47:0] sub48;
    input signed [47:0] a, b;
    sub48 = sat48(a - b);
  endfunction

  // Positive saturation limit for Q16.16
  localparam [31:0] Q16_16_MAX = 32'h7FFF_FFFF; // +32767.999984
  // 2^31 as 48-bit Q16.16 shift (for rounding to zero)
  localparam [47:0] P2_31_S48  = 48'h0000_8000_0000_0000;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      r0 <= 0; r1 <= 0; r2 <= 0; r3 <= 0;
      sum_s48 <= 0; mean <= 0; sum_abs <= 0; result <= 0;
      mad <= 0; done <= 0;
    end else begin
      state <= next;

      // Default pipeline hold-over
      r0 <= r0; r1 <= r1; r2 <= r2; r3 <= r3;
      sum_s48 <= sum_s48;
      mean <= mean;
      sum_abs <= sum_abs;
      result <= result;
      mad <= mad;
      done <= 1'b0; // one-cycle pulse in S_IDLE

      case (next)
        S_IDLE: begin
          if (start) begin
            r0 <= num0; r1 <= num1; r2 <= num2; r3 <= num3;
            // Sum in Q16.16 using 48-bit accumulator with saturation
            sum_s48 <= add48( add48( add48(48'(signed'(num0)), 48'(signed'(num1)) ),
                                      48'(signed'(num2)) ),
                              48'(signed'(num3)) );
          end
          mad <= 0;
          done <= 1'b0;
        end

        S_C1: begin
          // Pipeline registers already set in S_IDLE -> next transition
          // Hold sum stable; no action
        end

        S_C2: begin
          // Compute mean = round_toward_zero(sum/4) in Q16.16
          // sum_s48 is Q16.16 (16 fractional bits)
          if (sum_s48 >= 0) begin
            // Positive: divide by 4 then add 2^31 (rounding toward zero)
            mean <= ((sum_s48 >> 2) + P2_31_S48) >> 31;
          end else begin
            // Negative: divide by 4 then add (2^31 - 1) then shift
            mean <= (((sum_s48 >> 2) + (P2_31_S48 - 1)) >> 31);
          end
        end

        S_C3: begin
          // |x0 - mean| accumulate
          sum_abs <= add48( sum_abs, $unsigned(sub48(48'(signed'(r0)), 48'(signed'(mean)))) );
        end

        S_C4: begin
          // |x1 - mean| accumulate
          sum_abs <= add48( sum_abs, $unsigned(sub48(48'(signed'(r1)), 48'(signed'(mean)))) );
        end

        S_C5: begin
          // |x2 - mean| accumulate
          sum_abs <= add48( sum_abs, $unsigned(sub48(48'(signed'(r2)), 48'(signed'(mean)))) );
        end

        S_C6: begin
          // |x3 - mean| accumulate
          sum_abs <= add48( sum_abs, $unsigned(sub48(48'(signed'(r3)), 48'(signed'(mean)))) );
        end

        S_C7: begin
          // result = round_toward_zero(sum_abs / 4) in Q16.16
          if (sum_abs >= 0) begin
            result <= ((sum_abs >> 2) + P2_31_S48) >> 31;
          end else begin
            result <= (((sum_abs >> 2) + (P2_31_S48 - 1)) >> 31);
          end
        end

        default: begin
          // Should not occur
        end
      endcase

      // Output result one cycle after S_C7, in S_IDLE
      if (next == S_IDLE && state == S_C7) begin
        mad <= result;
        done <= 1'b1;
      end
    end
  end

  // Next-state logic
  always @(*) begin
    next = S_IDLE;
    case (state)
      S_IDLE: next = start ? S_C1 : S_IDLE;
      S_C1:   next = S_C2;
      S_C2:   next = S_C3;
      S_C3:   next = S_C4;
      S_C4:   next = S_C5;
      S_C5:   next = S_C6;
      S_C6:   next = S_C7;
      S_C7:   next = S_IDLE;
      default next = S_IDLE;
    endcase
  end

endmodule
