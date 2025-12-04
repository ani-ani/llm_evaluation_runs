module rescale_unit (
  input clk,
  input rst_n,
  input start,                   // Start computation (pulse)
  input [31:0] numbers [0:7],     // 8 Q16.16 numbers (32b each)
  output reg [31:0] result [0:7], // Rescaled Q16.16 values
  output reg done                 // High when computation completes (15 cycles from start)
);

  // Internal signals
  reg [31:0] min_val, max_val;
  reg [31:0] range_q16;           // max - min in Q16.16
  reg range_is_zero;

  // Division state (iterative subtraction, 15 cycles)
  reg [3:0] div_step;             // 0..15
  reg running;
  reg div_valid;                  // Indicates division in progress

  // Arrays to hold numerators and quotients for all 8 elements
  // All in Q16.16 format.
  reg [31:0] numer [0:7];         // numbers[i] - min_val (Q16.16)
  reg [15:0] quot [0:7];          // 0.16 result of (numer / range)

  integer i;

  // State machine for timing: 1 cycle to compute min/max, then 15 cycles to divide
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all state
      min_val <= 32'h0;
      max_val <= 32'h0;
      range_q16 <= 32'h0;
      range_is_zero <= 1'b0;
      div_step <= 4'd0;
      running <= 1'b0;
      div_valid <= 1'b0;
      done <= 1'b0;

      for (i = 0; i < 8; i = i + 1) begin
        numer[i] <= 32'h0;
        quot[i] <= 16'h0;
        result[i] <= 32'h0;
      end
    end else begin
      // Default: maintain current done until next start
      done <= 1'b0;

      if (start) begin
        // 1) Find min and max among the 8 inputs
        min_val <= numbers[0];
        max_val <= numbers[0];
        for (i = 1; i < 8; i = i + 1) begin
          if (numbers[i] < min_val) min_val <= numbers[i];
          if (numbers[i] > max_val) max_val <= numbers[i];
        end
        range_q16 <= numbers[0] - numbers[0]; // placeholder, overwritten below
        range_is_zero <= 1'b0;
        div_step <= 4'd0;
        running <= 1'b1;   // divide phase starts next cycle
        div_valid <= 1'b0; // will be asserted when range != 0
        done <= 1'b0;
      end else if (running) begin
        if (div_step == 4'd0) begin
          // Compute range = max - min
          range_q16 <= max_val - min_val;
          if (max_val == min_val) begin
            range_is_zero <= 1'b1;
            div_valid <= 1'b0; // Skip division; results will be 0
            // Prepare results as 0 (Q16.16 -> 0x00000000)
            for (i = 0; i < 8; i = i + 1) begin
              result[i] <= 32'h0;
              quot[i] <= 16'h0;
            end
            running <= 1'b0;   // Finish early
            done <= 1'b1;      // Completed in 1 cycle when range == 0
          end else begin
            range_is_zero <= 1'b0;
            div_valid <= 1'b1;
            // Initialize numerators and clear quotients
            for (i = 0; i < 8; i = i + 1) begin
              numer[i] <= numbers[i] - min_val; // Q16.16
              quot[i] <= 16'h0;                 // 0.16 result
            end
            div_step <= 4'd1; // move to first division cycle
          end
        end else if (div_valid) begin
          // Division: 15 cycles (steps 1..15)
          // Long division on Q16.16 / Q16.16 -> 0.16 result.
          // remainder is Q(16+1).16 (allow 1 extra integer bit to avoid overflow).
          for (i = 0; i < 8; i = i + 1) begin
            // 33-bit remainder = {numer[i][31:16], numer[i][15:0]}
            // 17-bit range    = {1'b0, range_q16[31:16]} to allow 0..(2^17-1)
            logic [32:0] rem;
            logic [16:0] divr;
            logic [31:0] next_numer;
            logic [15:0] next_quot;

            rem = { numer[i][31:16], numer[i][15:0] };
            divr = { 1'b0, range_q16[31:16] };

            if (rem >= divr) begin
              // Subtract range*2^(16 - step) from remainder, set the current bit
              next_numer = rem - { 1'b0, range_q16[31:0] };
              next_quot = quot[i] | (16'h8000 >> (div_step - 1));
            end else begin
              next_numer = rem;
              next_quot = quot[i];
            end

            // Update remainder for next step (shift left by 1, bring in next fractional bit)
            numer[i] <= { next_numer[30:0], 1'b0 };
            quot[i] <= next_quot;
          end

          if (div_step == 4'd15) begin
            // Final cycle: assemble result = quot << 16 (Q16.16)
            for (i = 0; i < 8; i = i + 1) begin
              result[i] <= { quot[i], 16'h0 };
            end
            running <= 1'b0;
            div_valid <= 1'b0;
            done <= 1'b1; // Latency: 1 (min/max) + 15 (division) = 16 cycles from start
          end else begin
            div_step <= div_step + 1;
          end
        end
      end
    end
  end

endmodule
