module theorem_dag_min_length (
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high)
  input [3:0] num_theorems, // 0-4 theorems (0 <= n <= 4)
  input [3:0] num_proofs [0:3], // Array of 4 elements (max 10 each)
  input [31:0] proof_lengths [0:3][0:9], // proof_lengths[thm][p]
  input [1:0] num_deps [0:3][0:9], // num_deps[thm][p] (max 3)
  input [1:0] deps [0:3][0:9][0:2], // deps[thm][proof][dep_idx]
  output reg [31:0] min_length, // Final result
  output reg done // High when computation completes
);

  // Local parameters
  localparam MAX_THEOREMS = 4;
  localparam MAX_PROOFS   = 10;
  localparam MAX_DEPS     = 3;
  localparam INF32        = 32'hFFFF_FFFF;

  // FSM states
  typedef enum logic [2:0] {
    IDLE          = 3'b000,
    INIT          = 3'b001,
    PROCESS_THM   = 3'b010,
    PROCESS_PROOF = 3'b011,
    UPDATE        = 3'b100,
    DONE          = 3'b101
  } state_t;

  state_t state, next_state;

  // Counters and control signals
  logic [3:0] thm_idx;   // current theorem index (0..3)
  logic [3:0] proof_idx; // current proof index (0..9)
  logic [1:0] dep_idx;   // current dependency index within a proof (0..2)
  logic [31:0] current_sum;     // accumulated length for current proof (p_len + deps)
  logic [31:0] current_thm_min; // best min length for current theorem
  logic finish_proof;   // high for 1 cycle when current proof is finished
  logic finish_theorem; // high for 1 cycle when current theorem is finished

  // Result storage
  logic [31:0] min_lengths [0:3];

  // Sequential logic: state, control, and storage
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      thm_idx        <= 4'd0;
      proof_idx      <= 4'd0;
      dep_idx        <= 2'd0;
      current_sum    <= 32'd0;
      current_thm_min<= INF32;
      min_length     <= 32'd0;
      done           <= 1'b0;
      finish_proof   <= 1'b0;
      finish_theorem <= 1'b0;
      min_lengths[0] <= INF32;
      min_lengths[1] <= INF32;
      min_lengths[2] <= INF32;
      min_lengths[3] <= INF32;
    end else begin
      // Defaults for pulse signals
      finish_proof   <= 1'b0;
      finish_theorem <= 1'b0;

      // State machine update
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize for computation
            thm_idx        <= 4'd0;
            proof_idx      <= 4'd0;
            dep_idx        <= 2'd0;
            current_sum    <= 32'd0;
            current_thm_min<= INF32;
            min_lengths[0] <= INF32;
            min_lengths[1] <= INF32;
            min_lengths[2] <= INF32;
            min_lengths[3] <= INF32;
            done           <= 1'b0;
            state          <= INIT;
          end
        end

        INIT: begin
          // Prepare first theorem
          thm_idx         <= 4'd0;
          proof_idx       <= 4'd0;
          dep_idx         <= 2'd0;
          current_sum     <= 32'd0;
          current_thm_min <= INF32;
          state           <= PROCESS_THM;
        end

        PROCESS_THM: begin
          if (thm_idx < num_theorems) begin
            // Enter proof processing for current theorem
            dep_idx         <= 2'd0;
            current_sum     <= 32'd0;
            state           <= PROCESS_PROOF;
          end else begin
            // No theorems to process
            state           <= DONE;
          end
        end

        PROCESS_PROOF: begin
          if (proof_idx < num_proofs[thm_idx]) begin
            if (dep_idx < num_deps[thm_idx][proof_idx]) begin
              // Accumulate dependency length (min_lengths for lower thms are already computed)
              if (dep_idx == 2'd0) begin
                // Start a fresh sum for this proof: base length + first dependency
                current_sum <= proof_lengths[thm_idx][proof_idx] + min_lengths[deps[thm_idx][proof_idx][dep_idx]];
              end else begin
                // Continue accumulating dependencies
                current_sum <= current_sum + min_lengths[deps[thm_idx][proof_idx][dep_idx]];
              end
              dep_idx <= dep_idx + 1;
            end else begin
              // Finished all dependencies for this proof: commit best for theorem
              if (current_sum < current_thm_min) begin
                current_thm_min <= current_sum;
              end
              finish_proof <= 1'b1;
              proof_idx    <= proof_idx + 1;
              dep_idx      <= 2'd0;
              current_sum  <= 32'd0;
              state        <= UPDATE;
            end
          end else begin
            // No more proofs for this theorem: update stored min and move to next theorem
            finish_theorem <= 1'b1;
            state          <= UPDATE;
          end
        end

        UPDATE: begin
          if (finish_proof) begin
            // Continue to next proof of the same theorem
            state <= PROCESS_PROOF;
          end else if (finish_theorem) begin
            // Store result for this theorem and move to next
            min_lengths[thm_idx] <= current_thm_min;
            // Capture final result for theorem 0 as soon as it is available
            if (thm_idx == 4'd0) begin
              min_length <= current_thm_min;
            end
            thm_idx     <= thm_idx + 1;
            proof_idx   <= 4'd0;
            dep_idx     <= 2'd0;
            current_sum <= 32'd0;
            state       <= PROCESS_THM;
          end
        end

        DONE: begin
          // Hold done high for 1 cycle as specified
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
