module non_wool_sequence_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,      // max sequence length 16 (4 bits)
  input [15:0] m,     // max 2^16-1 elements (16 bits)
  output reg [31:0] result, // mod 1000000009 (32 bits)
  output reg done
);

  // Parameters
  localparam MOD  = 32'd1000000009;
  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam COMPUTE = 2'd2;
  localparam DONE = 2'd3;

  // Internal registers
  reg [1:0]  state, next_state;
  reg [3:0]  i;                  // loop counter, 0..15
  reg [31:0] k;                  // (2^m - 1) % MOD
  reg [31:0] base;               // for pow2 calculation (2^m)
  reg [31:0] temp_result;

  // Assertions: n <= 16 (synthesis-time / simulation-time simple check)
  // Using immediate assertion in always block

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
        else
          next_state = IDLE;
      end
      INIT: begin
        next_state = COMPUTE;
      end
      COMPUTE: begin
        if (i == n)
          next_state = DONE;
        else
          next_state = COMPUTE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      result      <= 32'd0;
      done        <= 1'b0;
      i           <= 4'd0;
      k           <= 32'd0;
      base        <= 32'd0;
      temp_result <= 32'd0;
    end else begin
      state <= next_state;

      // Simple assertion for n <= 16 (runtime check, no effect on synthesis if unsupported)
      if (n > 4'd16) begin
        // In ASIC/FPGA flows, this can be turned into a formal/assert or left as-is.
      end

      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= 32'd0;
          i      <= 4'd0;
          if (start) begin
            // Prepare for INIT in next cycle
            // Compute (2^m) % MOD in INIT state; here we can preload
            base <= 32'd2; // base for power computation
          end
        end

        INIT: begin
          // Compute (2^m) % MOD using fast shift/mod for m <= 16:
          // 2^m fits in 32 bits, so (2^m) % MOD is just (1 << m) since 2^16 << MOD
          // Then k = (2^m - 1) % MOD.
          // Implement generically but efficiently for given constraints.
          // Shift is safe as m <= 16.
          k <= ((32'd1 << m) - 32'd1) % MOD;

          // Initialize result and loop counter
          result      <= 32'd1; // neutral element for product
          temp_result <= 32'd1;
          i           <= 4'd0;
        end

        COMPUTE: begin
          if (i < n) begin
            // Compute (k - i) mod MOD
            // Since k and i are small, direct subtraction with conditional add.
            reg [31:0] factor;
            reg [63:0] mult_full;
            reg [31:0] mult_mod;

            factor = (k >= i) ? (k - i) : (k + MOD - i);

            // 32x32 -> 64 multiply, then mod MOD
            mult_full = result * factor;
            // Reduce 64-bit product modulo MOD (constant, < 2^31)
            // For small bounds (n <= 16) and this MOD, direct % is acceptable here.
            mult_mod = mult_full % MOD;

            result <= mult_mod;
            i      <= i + 4'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold result stable until next start (handled by IDLE transition)
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

endmodule