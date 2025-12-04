module non_wool_sequence_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,      // max sequence length 16 (4 bits)
  input [15:0] m,     // max 2^16-1 elements (16 bits)
  output reg [31:0] result, // mod 1000000009 (32 bits)
  output reg done
);

  // Modulus for all operations
  localparam MOD = 32'd1000000009;

  // FSM states: IDLE(0), INIT(1), COMPUTE(2), DONE(3)
  typedef enum logic [1:0] { IDLE = 2'd0, INIT = 2'd1, COMPUTE = 2'd2, DONE = 3'd3 } state_t;
  state_t state, next_state;

  // Internal registers
  reg [31:0] k;           // cached (2^m - 1) % MOD
  reg [3:0] i;            // loop counter (0..15)
  reg [16:0] pow2_m;      // up to 2^16 (17 bits to hold 65536)
  reg [31:0] prod;        // temp for modular multiplication
  reg [31:0] k_minus_i;   // temp for (k - i)
  reg [31:0] mult_result; // result of modular multiplication
  reg mult_neg;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'd0;
      done <= 1'b0;
      k <= 32'd0;
      i <= 4'd0;
      pow2_m <= 17'd0;
      prod <= 32'd0;
      k_minus_i <= 32'd0;
      mult_result <= 32'd0;
      mult_neg <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs
      done <= 1'b0;

      // Compute k once in INIT (2^m - 1) % MOD using shift-and-add modular exponentiation
      if (state == INIT) begin
        pow2_m <= 17'd1;      // start with 2^0
        k <= 32'd0;           // accumulator for 2^m mod MOD
        i <= 5'd0;            // counter for bits 0..15 (use 5 bits to count 0..16)
      end else if (state == COMPUTE) begin
        // k is already computed and held; do nothing to k here
      end else begin
        // Hold k in other states (IDLE, DONE)
      end

      // Modular multiplication step (pipelined into next_state result update)
      // We compute the multiply in COMPUTE and update result when transitioning to next_state.
      if (state == COMPUTE) begin
        // k is stable; compute (k - i) % MOD safely
        if (i <= k[3:0]) begin
          k_minus_i <= k - i;
        end else begin
          k_minus_i <= (k + MOD) - i;
        end
        // 32-bit modular multiplication (result = (a * b) % MOD) without 64-bit ops
        // Split multiplier to 16-bit parts to avoid overflow
        prod <= k_minus_i * result;
        mult_result <= ((k_minus_i[31:16] * result) << 16) +
                       (({16'd0, k_minus_i[15:0]} * result) >> 16);
        mult_neg <= (k_minus_i[31] ^ result[31]) && mult_result[31];
      end

      // Update result based on next_state transitions
      case (next_state)
        IDLE: begin
          result <= 32'd0;
          i <= 4'd0;
          pow2_m <= 17'd0;
        end
        INIT: begin
          // Prepare k via shift-and-add modular exponentiation across this state
          // This iteration uses pow2_m (current 2^i mod MOD) and multiplies by 2
          if (i < 5'd16) begin
            pow2_m <= pow2_m + pow2_m;                // multiply by 2
            k <= (k + k) % MOD;                        // (2^i -> 2^(i+1)) mod MOD
            i <= i + 1;
          end else begin
            // k holds 2^16 mod MOD; finalize (2^m - 1) % MOD with current m
            // For m==16, k is already 2^16 mod MOD; subtract 1.
            // For m<16, we must adjust: k currently equals 2^16 mod MOD regardless of m.
            // To correct, use: (2^m - 1) % MOD = (k * inv_pow2_16_minus_m - 1) % MOD
            // Instead, simpler: recompute 2^m properly if m != 16.
            // This block re-computes 2^m from scratch correctly for any m.
            // Start a mini-loop to build 2^m in pow2_m and k (reuse same mechanism):
            // Reset and compute from scratch; will be stable next cycle.
            pow2_m <= 17'd1;
            k <= 32'd1;
            i <= 5'd0;
          end
          result <= 32'd1;   // accumulator for product chain
        end
        COMPUTE: begin
          // Update loop counter and apply modular multiplication result from previous cycle
          if (i < n) begin
            // Apply the modular multiply result computed in the prior cycle
            result <= mult_neg ? (mult_result + MOD) : mult_result;
            i <= i + 1;
          end
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          // Stay safe
        end
      endcase
    end
  end

  // Compute k in INIT across cycles: finalize with current m when i reaches m
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        // If m == 16, we reach i==16 and k == 2^16 % MOD; finalize now
        // If m < 16, we detect i==m and finalize there
        if (i == {1'b0, m}) begin
          k = (k + MOD - 1) % MOD;  // ensure non-negative (2^m - 1) % MOD
          next_state = COMPUTE;
        end
      end
      COMPUTE: begin
        if (i >= n) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule
