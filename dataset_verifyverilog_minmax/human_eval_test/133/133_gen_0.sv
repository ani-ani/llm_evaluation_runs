module ceil_sum_squares(
  input clk,
  input rst_n, // active-low reset
  input start,  // pulse high to start
  input [31:0] data_in [0:7], // 8 elements of Q16.16 fixed-point numbers
  output reg [31:0] result, // integer result (fractional bits ignored)
  output reg done // high when result is valid
);

  // State machine states
  localparam IDLE = 1'b0;
  localparam RUN  = 1'b1;

  reg state;
  reg [3:0] cnt;            // 0..10; cycle 11 sets done
  reg [63:0] sum_sq;        // accumulator for sum of squares
  reg [31:0] din_r [0:7];   // captured input data
  reg [31:0] ceiled;        // ceiling-rounded Q16.16 -> Q16.16
  reg [63:0] sq;            // square result (64-bit)
  integer i;

  // Ceiling function for Q16.16 with per-element rule:
  // - if fractional == 0 -> no change
  // - if fractional != 0 and value > 0 -> integer++
  // - if value < 0 -> truncate towards zero (reverse floor)
  function [31:0] q16_16_ceiling_q16_16(input [31:0] x);
    reg [15:0] frac;
    reg [31:0] int_part;
    reg [31:0] y;
  begin
    int_part = $signed(x) >>> 16;               // signed integer part
    frac     = x[15:0];                         // 16-bit fractional part
    y        = {int_part[15:0], 16'h0000};      // Q16.16 with zero frac
    if (frac != 16'h0) begin
      if ($signed(x) > 0) y = y + 32'h0001_0000;      // positive: round up
      else               y = $unsigned($signed(y));  // negative: truncate towards zero
    end
    q16_16_ceiling_q16_16 = y;
  end
  endfunction

  always @(posedge clk) begin
    if (~rst_n) begin
      state    <= IDLE;
      cnt      <= 4'h0;
      result   <= 32'h0;
      done     <= 1'b0;
      sum_sq   <= 64'h0;
      ceiled   <= 32'h0;
      sq       <= 64'h0;
      for (i = 0; i < 8; i = i + 1) din_r[i] <= 32'h0;
    end else begin
      // Defaults
      ceiled <= 32'h0;
      sq     <= 64'h0;

      if (start) begin
        // Start/restart operation
        state <= RUN;
        cnt   <= 4'h0;  // will represent cycle 0
        done  <= 1'b0;
        sum_sq <= 64'h0;
        // Capture input array at start of cycle
        for (i = 0; i < 8; i = i + 1) din_r[i] <= data_in[i];
      end else if (state == RUN) begin
        // Processing loop
        if (cnt < 4'h8) begin
          ceiled <= q16_16_ceiling_q16_16(din_r[cnt]);
          sq     <= $signed(ceiled) * $signed(ceiled);
          sum_sq <= sum_sq + sq;
          cnt    <= cnt + 1;
        end else begin
          // At cycle 8: no new sq added (element 8 doesn't exist)
          if (cnt == 4'h8) begin
            cnt <= 4'h9;
          end else if (cnt == 4'h9) begin
            // Cycle 9: pipeline flush, prepare result
            result <= sum_sq[47:16]; // shift right 16 to drop fractional bits
            cnt    <= 4'hA;
          end else if (cnt == 4'hA) begin
            // Cycle 10: result is already valid; set done on next cycle
            done <= 1'b1;
            cnt  <= 4'hB;
          end else begin
            // Cycle 11: done high as required
            done <= 1'b1;
            cnt  <= 4'hB; // stay here until next start
          end
        end
      end else begin
        // IDLE (and not started this cycle): hold done low
        done <= 1'b0;
      end
    end
  end

endmodule
