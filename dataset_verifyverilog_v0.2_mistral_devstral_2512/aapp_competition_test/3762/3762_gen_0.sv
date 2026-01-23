module perfect_sets (
  input clk,
  input rst_n,
  input start,
  input [15:0] k,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam MOD = 32'd1000000007;
  localparam IDLE = 2'd0;
  localparam PROCESS_BIT = 2'd1;
  localparam COMPUTE_DONE = 2'd2;

  // State machine
  reg [1:0] state = IDLE;
  reg [3:0] bit_idx = 4'd15; // Start from MSB (bit 15)
  reg [31:0] dp_tight = 1; // DP state for tight constraint
  reg [31:0] dp_loose = 1; // DP state for loose constraint
  reg [31:0] temp_tight, temp_loose;
  reg [31:0] count = 0;

  // Modular addition function
  function [31:0] mod_add;
    input [31:0] a, b;
    begin
      mod_add = (a + b) % MOD;
    end
  endfunction

  // Modular multiplication function
  function [31:0] mod_mul;
    input [31:0] a, b;
    begin
      mod_mul = (a * b) % MOD;
    end
  endfunction

  // Modular power function (for 2^basis_count)
  function [31:0] mod_pow;
    input [31:0] base, exp;
    reg [31:0] result_pow = 1;
    reg [31:0] b = base;
    reg [31:0] e = exp;
    begin
      while (e > 0) begin
        if (e[0]) result_pow = mod_mul(result_pow, b);
        b = mod_mul(b, b);
        e = e >> 1;
      end
      mod_pow = result_pow;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      bit_idx <= 4'd15;
      dp_tight <= 1;
      dp_loose <= 1;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS_BIT;
            bit_idx <= 4'd15;
            dp_tight <= 1;
            dp_loose <= 1;
            done <= 0;
          end
        end

        PROCESS_BIT: begin
          if (bit_idx == 0) begin
            state <= COMPUTE_DONE;
          end else begin
            // Process current bit
            temp_tight = 0;
            temp_loose = 0;

            if (k[bit_idx]) begin
              // Case 1: Tight constraint (bit must match)
              // Can choose to add new basis element (must set this bit)
              // Or not add (but then must have 0 in this bit)
              temp_tight = mod_add(dp_tight, dp_tight); // 2 * dp_tight
              // Case 2: Loose constraint (bit can be 0)
              // Can choose to add new basis element (can set this bit to 0 or 1)
              // Or not add (must have 0 in this bit)
              temp_loose = mod_add(dp_loose, mod_mul(dp_loose, 2));
            end else begin
              // Current bit of k is 0
              // Only option is to not add new basis element
              // Existing basis elements can contribute 0 or 1 in this bit position
              temp_tight = mod_mul(dp_tight, 2);
              temp_loose = mod_mul(dp_loose, 2);
            end

            dp_tight <= temp_tight;
            dp_loose <= temp_loose;
            bit_idx <= bit_idx - 1;
          end
        end

        COMPUTE_DONE: begin
          // Final computation: sum over all valid basis counts
          // For tight constraint, we need to ensure the set includes k
          // For loose constraint, we can have any valid set
          count = mod_add(dp_tight, dp_loose);
          // Subtract 1 to exclude the empty set (which doesn't contain k)
          // But since all perfect sets must contain 0, we need to adjust
          // Actually, the empty set is not valid as it doesn't contain 0
          // So we don't need to subtract anything

          result <= count;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule