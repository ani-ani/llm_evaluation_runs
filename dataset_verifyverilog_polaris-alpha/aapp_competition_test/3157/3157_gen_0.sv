module hash_word_counter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] N, // word length (1-10)
  input [24:0] K, // target hash value (0 <= K < 2^M)
  input [4:0] M, // modulo exponent (6-25, MOD = 2^M)
  output reg [46:0] count, // number of valid words
  output reg done // high when computation complete
);

  // State encoding
  localparam IDLE       = 2'd0;
  localparam INIT       = 2'd1;
  localparam PROCESSING = 2'd2;
  localparam DONE       = 2'd3;

  reg [1:0]  state, next_state;

  // Internal registers
  reg [3:0]  step;              // current position (1..N)
  reg [24:0] mod_mask;          // (1<<M)-1
  reg [24:0] target_hash_reg;   // latched K
  reg [3:0]  N_reg;             // latched N
  reg [4:0]  M_reg;             // latched M

  // DP arrays: use only indices [0 .. (1<<M_reg)-1]
  reg [46:0] dp_prev [0:(1<<25)-1];
  reg [46:0] dp_curr [0:(1<<25)-1];

  // Iteration indices
  reg [24:0] prev_hash_idx;
  reg [4:0]  letter_idx;  // 1..26

  // Control flags
  reg init_phase;          // indicates INIT cycle has run
  reg processing_done;     // indicates N processing cycles completed

  // Combinational wires
  wire [24:0] new_hash;
  assign new_hash = (((prev_hash_idx * 25'd33) ^ letter_idx) & mod_mask);

  integer i;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end
      end
      INIT: begin
        next_state = PROCESSING;
      end
      PROCESSING: begin
        if (processing_done) begin
          next_state = DONE;
        end
      end
      DONE: begin
        // Stay in DONE until next start (synchronous via state machine)
        if (start) begin
          next_state = INIT;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      step             <= 4'd0;
      mod_mask         <= 25'd0;
      target_hash_reg  <= 25'd0;
      N_reg            <= 4'd0;
      M_reg            <= 5'd0;
      prev_hash_idx    <= 25'd0;
      letter_idx       <= 5'd0;
      init_phase       <= 1'b0;
      processing_done  <= 1'b0;
      count            <= 47'd0;
      done             <= 1'b0;
      // Clear DP tables
      for (i = 0; i < (1<<25); i = i + 1) begin
        dp_prev[i] <= 47'd0;
        dp_curr[i] <= 47'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done            <= 1'b0;
          processing_done <= 1'b0;
          init_phase      <= 1'b0;
          if (start) begin
            // Latch inputs
            N_reg           <= N;
            M_reg           <= M;
            target_hash_reg <= K;
            mod_mask        <= (25'd1 << M) - 1'b1;
            // Initialize indices and counters
            step            <= 4'd0;
            prev_hash_idx   <= 25'd0;
            letter_idx      <= 5'd0;
            // Clear DP tables; set base condition next cycle in INIT
            for (i = 0; i < (1<<25); i = i + 1) begin
              dp_prev[i] <= 47'd0;
              dp_curr[i] <= 47'd0;
            end
          end
        end

        INIT: begin
          // Base: DP[0][0] = 1
          dp_prev[25'd0] <= 47'd1;
          // All others assumed 0 from previous clears
          step           <= 4'd0;
          prev_hash_idx  <= 25'd0;
          letter_idx     <= 5'd1;
          init_phase     <= 1'b1;
        end

        PROCESSING: begin
          if (!processing_done) begin
            // Dynamic programming iteration over N cycles
            // For this cycle, we conceptually process transitions from dp_prev
            // NOTE: This is a conceptual fully unrolled DP; hardware-wise this
            // is not practical for 2^25 states but follows the specification.

            // When starting a new step, clear dp_curr
            if (prev_hash_idx == 25'd0 && letter_idx == 5'd1) begin
              for (i = 0; i < (1<<25); i = i + 1) begin
                dp_curr[i] <= 47'd0;
              end
            end

            // Accumulate transitions for current prev_hash_idx and letter_idx
            if (dp_prev[prev_hash_idx] != 47'd0 && letter_idx >= 5'd1 && letter_idx <= 5'd26) begin
              dp_curr[new_hash] <= dp_curr[new_hash] + dp_prev[prev_hash_idx];
            end

            // Advance letter index
            if (letter_idx < 5'd26) begin
              letter_idx <= letter_idx + 5'd1;
            end else begin
              letter_idx <= 5'd1;
              // Move to next prev_hash_idx
              if (prev_hash_idx < mod_mask) begin
                prev_hash_idx <= prev_hash_idx + 25'd1;
              end else begin
                // Completed all prev_hash for this step
                // Copy dp_curr into dp_prev for next step
                for (i = 0; i <= mod_mask; i = i + 1) begin
                  dp_prev[i] <= dp_curr[i];
                end
                prev_hash_idx <= 25'd0;
                // Increment step count
                step <= step + 4'd1;
                // Check if all N steps completed
                if (step + 4'd1 >= N_reg) begin
                  processing_done <= 1'b1;
                end
              end
            end
          end
        end

        DONE: begin
          // Output result after processing
          count <= dp_prev[target_hash_reg & mod_mask];
          done  <= 1'b1;
          // Wait for next start to move to INIT (handled in next_state)
        end

        default: begin
          // Should not occur; safely go to IDLE
          state <= IDLE;
        end
      endcase
    end
  end

endmodule