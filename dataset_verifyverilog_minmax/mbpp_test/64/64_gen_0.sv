module sort_by_score(
  input clk,
  input start,
  input rst_n,
  input [3:0][7:0] scores,
  output logic [3:0][7:0] sorted_scores,
  output logic [3:0][1:0] sorted_indices,
  output logic done
);

  typedef enum logic [1:0] {IDLE, COMPARE, SWAP, DONE} state_t;
  state_t state, next_state;

  logic [3:0][7:0] s_reg, s_next;
  logic [3:0][1:0] idx_reg, idx_next;

  logic [1:0] pass;       // 0..2 (3 passes for 4 elements)
  logic [1:0] cmp_idx;    // 0..2 (comparisons 0-2 each pass)
  logic swap;

  assign swap = s_reg[cmp_idx] > s_reg[cmp_idx + 1];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      s_reg <= '0;
      idx_reg <= '0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      s_reg <= s_next;
      idx_reg <= idx_next;
      done <= (next_state == DONE);
    end
  end

  always_comb begin
    // Defaults
    s_next = s_reg;
    idx_next = idx_reg;
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          s_next = scores;   // latch inputs when starting
          idx_next = '0;     // {0,1,2,3} via bit assignment below
          idx_next[0] = 2'd0;
          idx_next[1] = 2'd1;
          idx_next[2] = 2'd2;
          idx_next[3] = 2'd3;
          pass = 2'd0;
          cmp_idx = 2'd0;
          next_state = COMPARE;
        end else begin
          next_state = IDLE;
        end
      end

      COMPARE: begin
        if (swap) begin
          // Swap scores and corresponding indices
          s_next[cmp_idx]     = s_reg[cmp_idx + 1];
          s_next[cmp_idx + 1] = s_reg[cmp_idx];
          idx_next[cmp_idx]     = idx_reg[cmp_idx + 1];
          idx_next[cmp_idx + 1] = idx_reg[cmp_idx];
          next_state = SWAP;
        end else begin
          next_state = COMPARE;
        end
        // Update indices for next comparison
        if (cmp_idx == 2'd2) begin
          cmp_idx = 2'd0;
          pass = (pass == 2'd2) ? 2'd0 : (pass + 1);
        end else begin
          cmp_idx = cmp_idx + 1;
        end
      end

      SWAP: begin
        next_state = COMPARE;
      end

      DONE: begin
        if (start) begin
          // Re-start on new start pulse
          s_next = scores;
          idx_next = '0;
          idx_next[0] = 2'd0;
          idx_next[1] = 2'd1;
          idx_next[2] = 2'd2;
          idx_next[3] = 2'd3;
          pass = 2'd0;
          cmp_idx = 2'd0;
          next_state = COMPARE;
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Outputs
  assign sorted_scores = s_reg;
  assign sorted_indices = idx_reg;

endmodule
