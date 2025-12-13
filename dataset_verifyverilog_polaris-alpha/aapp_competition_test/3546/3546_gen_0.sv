module theorem_dag_min_length(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_theorems,
  input [3:0] num_proofs [0:3],
  input [31:0] proof_lengths [0:3][0:9],
  input [1:0] num_deps [0:3][0:9],
  input [1:0] deps [0:3][0:9][0:2],
  output reg [31:0] min_length,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    INIT          = 3'd1,
    PROCESS_THM   = 3'd2,
    PROCESS_PROOF = 3'd3,
    UPDATE        = 3'd4,
    DONE_STATE    = 3'd5
  } state_t;

  state_t state, next_state;

  // Indices and counters
  reg [1:0] thm_idx;          // 0..3
  reg [3:0] proof_idx;        // 0..9
  reg [1:0] dep_idx;          // 0..2

  // Storage for per-theorem minimal lengths
  reg [31:0] min_lengths [0:3];

  // Current theorem bookkeeping
  reg [31:0] best_len_cur_thm;     // best length found for current theorem
  reg        best_len_valid;       // whether best_len_cur_thm is valid

  // Current proof accumulation
  reg [31:0] curr_proof_len;       // base length for current proof
  reg [31:0] curr_total_len;       // base + deps

  // Latched configuration
  reg [3:0] num_theorems_q;

  // Helper wires
  wire [3:0] num_proofs_cur   = num_proofs[thm_idx];
  wire [1:0] num_deps_cur_pf  = num_deps[thm_idx][proof_idx];
  wire [31:0] proof_len_cur   = proof_lengths[thm_idx][proof_idx];

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // Move directly to PROCESS_THM
        next_state = PROCESS_THM;
      end

      PROCESS_THM: begin
        // If all theorems done -> DONE_STATE
        if (thm_idx >= num_theorems_q)
          next_state = DONE_STATE;
        else begin
          // If no proofs for this theorem, stay safe: we'll treat as max and move on
          if (num_proofs_cur == 0)
            next_state = UPDATE;
          else
            next_state = PROCESS_PROOF;
        end
      end

      PROCESS_PROOF: begin
        // In this state we iterate deps via dep_idx and then move to UPDATE
        // Transition controlled in sequential always based on dep completion
        // Default hold, overridden below using conditions
        if (dep_idx == num_deps_cur_pf) begin
          // finished deps accumulation for this proof
          next_state = UPDATE;
        end else begin
          // still processing deps; remain in PROCESS_PROOF
          next_state = PROCESS_PROOF;
        end
      end

      UPDATE: begin
        // Decide next proof or next theorem or done
        if (proof_idx + 1 < num_proofs_cur) begin
          // More proofs for this theorem
          next_state = PROCESS_PROOF;
        end else begin
          // No more proofs; go to next theorem
          next_state = PROCESS_THM;
        end
      end

      DONE_STATE: begin
        // Assert done for one cycle then go IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      done            <= 1'b0;
      min_length      <= 32'd0;
      num_theorems_q  <= 4'd0;
      thm_idx         <= 2'd0;
      proof_idx       <= 4'd0;
      dep_idx         <= 2'd0;
      best_len_cur_thm<= 32'hFFFFFFFF;
      best_len_valid  <= 1'b0;
      curr_proof_len  <= 32'd0;
      curr_total_len  <= 32'd0;
      for (i = 0; i < 4; i = i + 1) begin
        min_lengths[i] <= 32'hFFFFFFFF;
      end
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, may be set in DONE_STATE

      case (state)
        IDLE: begin
          if (start) begin
            // Latch number of theorems and init
            num_theorems_q <= num_theorems;
            thm_idx        <= 2'd0;
            proof_idx      <= 4'd0;
            dep_idx        <= 2'd0;
            best_len_cur_thm <= 32'hFFFFFFFF;
            best_len_valid   <= 1'b0;
            curr_proof_len   <= 32'd0;
            curr_total_len   <= 32'd0;
            for (i = 0; i < 4; i = i + 1) begin
              min_lengths[i] <= 32'hFFFFFFFF;
            end
          end
        end

        INIT: begin
          // Nothing more; all init done in IDLE on start
          // Prepare first theorem
          thm_idx          <= 2'd0;
          proof_idx        <= 4'd0;
          dep_idx          <= 2'd0;
          best_len_cur_thm <= 32'hFFFFFFFF;
          best_len_valid   <= 1'b0;
          curr_proof_len   <= 32'd0;
          curr_total_len   <= 32'd0;
        end

        PROCESS_THM: begin
          if (thm_idx >= num_theorems_q) begin
            // All theorems done; nothing here, DONE_STATE will handle
          end else begin
            // Starting processing of theorem thm_idx
            best_len_cur_thm <= 32'hFFFFFFFF;
            best_len_valid   <= 1'b0;
            proof_idx        <= 4'd0;
            dep_idx          <= 2'd0;
            curr_proof_len   <= 32'd0;
            curr_total_len   <= 32'd0;
          end
        end

        PROCESS_PROOF: begin
          if (!best_len_valid && proof_idx == 0 && dep_idx == 0 && curr_total_len == 0 && curr_proof_len == 0) begin
            // First entry for theorem or after reset of pointers; load base len
            curr_proof_len <= proof_len_cur;
            curr_total_len <= proof_len_cur;
          end

          // If we just entered this proof (dep_idx==0) and curr_total_len==0, ensure proper init
          if (dep_idx == 0 && curr_total_len == 0) begin
            curr_proof_len <= proof_len_cur;
            curr_total_len <= proof_len_cur;
          end

          if (dep_idx < num_deps_cur_pf) begin
            // Add dependency min length
            // dependency theorem index
            reg [1:0] dthm;
            dthm = deps[thm_idx][proof_idx][dep_idx];
            curr_total_len <= curr_total_len + min_lengths[dthm];
            dep_idx        <= dep_idx + 1'b1;
          end
          // when dep_idx == num_deps_cur_pf, next_state will move to UPDATE
        end

        UPDATE: begin
          // We have curr_total_len for current proof; update best length
          if (!best_len_valid || (curr_total_len < best_len_cur_thm)) begin
            best_len_cur_thm <= curr_total_len;
            best_len_valid   <= 1'b1;
          end

          if (proof_idx + 1 < num_proofs_cur) begin
            // Move to next proof for same theorem
            proof_idx      <= proof_idx + 1'b1;
            dep_idx        <= 2'd0;
            curr_proof_len <= 32'd0;
            curr_total_len <= 32'd0;
          end else begin
            // No more proofs: finalize theorem's min length
            min_lengths[thm_idx] <= (best_len_valid ? best_len_cur_thm : 32'hFFFFFFFF);

            // Move to next theorem
            thm_idx          <= thm_idx + 1'b1;
            proof_idx        <= 4'd0;
            dep_idx          <= 2'd0;
            best_len_cur_thm <= 32'hFFFFFFFF;
            best_len_valid   <= 1'b0;
            curr_proof_len   <= 32'd0;
            curr_total_len   <= 32'd0;
          end
        end

        DONE_STATE: begin
          // Theorem 0 min_length output
          min_length <= min_lengths[0];
          done       <= 1'b1; // assert for this cycle
          // Next state (IDLE) on next clock by FSM
        end

        default: begin
          // Should not occur, reset-like behavior
          state <= IDLE;
        end
      endcase
    end
  end

endmodule