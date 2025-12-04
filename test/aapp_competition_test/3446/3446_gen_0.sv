module optimal_assembler(
  input clk,
  input rst_n,
  input start,
  input [2:0] k, // unused per problem statement
  input [7:0][2:0] symbols, // unused per problem statement
  input [7:0][7:0][15:0] time_table,
  input [7:0][7:0][2:0] result_table,
  input [3:0] seq_len,
  input [7:0][2:0] seq,
  output reg [15:0] min_time,
  output reg [2:0] result_sym,
  output reg done
);

  // DP tables
  reg [15:0] dp [0:7][0:7];
  reg [2:0]  sym[0:7][0:7];

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_L_SETUP   = 3'd2,
    S_I_SETUP   = 3'd3,
    S_K_SETUP   = 3'd4,
    S_K_EVAL    = 3'd5,
    S_STORE     = 3'd6,
    S_DONE      = 3'd7
  } state_t;

  state_t state, next_state;

  // Control indices
  reg [3:0] cur_len;        // current subsequence length l (2..seq_len)
  reg [3:0] i_idx;          // start index i
  reg [3:0] j_idx;          // end index j
  reg [3:0] k_idx;          // split index k

  // Current best for (i,j)
  reg [15:0] cur_min_time;
  reg [2:0]  cur_min_sym;

  // Signals from DP tables for current k
  reg [15:0] left_time;
  reg [15:0] right_time;
  reg [2:0]  left_sym;
  reg [2:0]  right_sym;
  reg [15:0] combine_time;
  reg [15:0] total_time;
  reg [2:0]  total_sym;

  // Helper wires
  wire [3:0] last_idx = seq_len - 1'b1;

  // Sequential state / registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      cur_len      <= 4'd0;
      i_idx        <= 4'd0;
      j_idx        <= 4'd0;
      k_idx        <= 4'd0;
      cur_min_time <= 16'hFFFF;
      cur_min_sym  <= 3'd0;
      min_time     <= 16'd0;
      result_sym   <= 3'd0;
      done         <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // initialize diagonals: dp[i][i]=0, sym[i][i]=seq[i]
            // done incrementally in S_INIT
            cur_len <= 4'd0;
            i_idx   <= 4'd0;
          end
        end

        S_INIT: begin
          // For each i in [0, seq_len-1]: set base cases
          if (i_idx < seq_len) begin
            dp[i_idx][i_idx]  <= 16'd0;
            sym[i_idx][i_idx] <= seq[i_idx];
            i_idx             <= i_idx + 4'd1;
          end
        end

        S_L_SETUP: begin
          // prepare for processing length = cur_len
          i_idx   <= 4'd0;
        end

        S_I_SETUP: begin
          // compute j for this i and cur_len, and init best
          j_idx        <= i_idx + cur_len - 4'd1;
          k_idx        <= i_idx;
          cur_min_time <= 16'hFFFF;
          cur_min_sym  <= 3'd0;
        end

        S_K_SETUP: begin
          // latch left/right partial results for current k
          left_time  <= dp[i_idx][k_idx];
          right_time <= dp[k_idx+1][j_idx];
          left_sym   <= sym[i_idx][k_idx];
          right_sym  <= sym[k_idx+1][j_idx];
        end

        S_K_EVAL: begin
          // use latched left/right, compute candidate
          combine_time <= time_table[left_sym][right_sym];
          total_time   <= left_time + right_time + time_table[left_sym][right_sym];
          total_sym    <= result_table[left_sym][right_sym];

          if (total_time < cur_min_time) begin
            cur_min_time <= total_time;
            cur_min_sym  <= total_sym;
          end

          // advance k
          if (k_idx < (j_idx - 1)) begin
            k_idx <= k_idx + 4'd1;
          end
        end

        S_STORE: begin
          // store best for (i,j)
          dp[i_idx][j_idx]  <= cur_min_time;
          sym[i_idx][j_idx] <= cur_min_sym;

          // move to next (i) for current length
          i_idx <= i_idx + 4'd1;
        end

        S_DONE: begin
          // latch final answer
          min_time   <= dp[0][last_idx];
          result_sym <= sym[0][last_idx];
          done       <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT;
        end
      end

      S_INIT: begin
        if (!start) begin
          // wait until start deasserts to avoid retriggering
          if (i_idx >= seq_len) begin
            // move to first length iteration if seq_len >= 2, else directly done
            if (seq_len >= 4'd2) begin
              next_state = S_L_SETUP;
            end else if (seq_len >= 4'd1) begin
              next_state = S_DONE;
            end else begin
              next_state = S_IDLE;
            end
          end
        end
      end

      S_L_SETUP: begin
        // start with i=0 for this length
        // cur_len not yet incremented here; manage below
        if (cur_len == 4'd0) begin
          // first entry after INIT
          next_state = S_L_SETUP; // will be overridden by length update below
        end
        next_state = S_I_SETUP;
      end

      S_I_SETUP: begin
        // compute j and check bounds
        if ((i_idx + cur_len - 4'd1) <= last_idx) begin
          next_state = S_K_SETUP;
        end else begin
          // finished all i for this length; move to next length
          if (cur_len < seq_len) begin
            next_state = S_L_SETUP;
          end else begin
            next_state = S_DONE;
          end
        end
      end

      S_K_SETUP: begin
        // after latching left/right, move to evaluation
        next_state = S_K_EVAL;
      end

      S_K_EVAL: begin
        // if more k to try, go back to setup for next k, else store result
        if (k_idx < (j_idx - 1)) begin
          next_state = S_K_SETUP;
        end else begin
          next_state = S_STORE;
        end
      end

      S_STORE: begin
        // after storing, move to next i or next length or done
        if ((i_idx + 4'd1) + cur_len - 4'd1 <= last_idx) begin
          // next i for same length
          next_state = S_I_SETUP;
        end else begin
          // done all i for this length, move to next length
          if (cur_len < seq_len) begin
            next_state = S_L_SETUP;
          end else begin
            next_state = S_DONE;
          end
        end
      end

      S_DONE: begin
        // stay done until start is deasserted and asserted again
        if (!start) begin
          next_state = S_IDLE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Manage cur_len updates (separate from main FSM for clarity)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_len <= 4'd0;
    end else begin
      case (state)
        S_INIT: begin
          if (i_idx >= seq_len && !start) begin
            if (seq_len >= 4'd2) begin
              cur_len <= 4'd2;
            end else begin
              cur_len <= seq_len; // 0 or 1
            end
          end
        end
        S_STORE: begin
          // when finishing all i for current length, bump cur_len
          if (((i_idx + 4'd1) + cur_len - 4'd1) > last_idx) begin
            if (cur_len < seq_len)
              cur_len <= cur_len + 4'd1;
          end
        end
        S_IDLE: begin
          if (start) cur_len <= 4'd0;
        end
        default: ;
      endcase
    end
  end

endmodule