module optimal_assembler(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [7:0][2:0] symbols,
  input [7:0][7:0][15:0] time_table,
  input [7:0][7:0][2:0] result_table,
  input [3:0] seq_len,
  input [7:0][2:0] seq,
  output reg [15:0] min_time,
  output reg [2:0] result_sym,
  output reg done
);

  // DP tables for up to 8 elements
  logic [15:0] dp [0:7][0:7];
  logic [2:0]  sym[0:7][0:7];

  // State machine
  typedef enum logic [2:0] {
    S_IDLE = 3'd0,
    S_INIT = 3'd1,
    S_L_PREP = 3'd2,
    S_I_PREP = 3'd3,
    S_K_LOOP = 3'd4,
    S_UPDATE = 3'd5,
    S_DONE = 3'd6
  } state_t;
  state_t state, next_state;

  // Counters
  logic [3:0] l_cnt, l_next;      // subsequence length (2..seq_len)
  logic [3:0] i_cnt, i_next;      // start index i
  logic [3:0] k_cnt, k_next;      // split point k

  // Temporary/intermediate values
  logic [3:0] j;
  logic [15:0] left_time, right_time, combine_time, total_time, best_time, best_time_next;
  logic [2:0]  left_sym, right_sym, best_sym, best_sym_next;
  logic        has_best, has_best_next;
  logic        left_is_min, right_is_min;
  logic [15:0] min_time_next;
  logic [2:0]  result_sym_next;
  logic        done_next;

  // Address aliases (width extension to 3 bits for array indexing)
  wire [2:0] i_addr = i_cnt[2:0];
  wire [2:0] j_addr = j[2:0];
  wire [2:0] k_addr = k_cnt[2:0];

  // Compute left/right mins and j for current (l,i)
  always_comb begin
    j = i_cnt + l_cnt - 1;
    left_time  = dp[i_addr][i_addr];
    left_sym   = sym[i_addr][i_addr];
    right_time = dp[k_addr+1][j_addr];
    right_sym  = sym[k_addr+1][j_addr];
    left_is_min  = (left_time <= right_time);
    right_is_min = (right_time < left_time);
    combine_time = left_is_min ? time_table[left_sym][right_sym] : time_table[right_sym][left_sym];
    total_time   = left_time + right_time + combine_time;
  end

  // State and counters sequencing
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      l_cnt <= 4'd0;
      i_cnt <= 4'd0;
      k_cnt <= 4'd0;
      has_best <= 1'b0;
      best_time <= 16'h0;
      best_sym <= 3'd0;
      dp <= '{default:16'h0};
      sym <= '{default:3'd0};
      min_time <= 16'h0;
      result_sym <= 3'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      l_cnt <= l_next;
      i_cnt <= i_next;
      k_cnt <= k_next;
      has_best <= has_best_next;
      best_time <= best_time_next;
      best_sym <= best_sym_next;
      dp <= dp; // Hold
      sym <= sym; // Hold
      min_time <= min_time_next;
      result_sym <= result_sym_next;
      done <= done_next;
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults
    next_state = state;
    l_next = l_cnt;
    i_next = i_cnt;
    k_next = k_cnt;
    has_best_next = has_best;
    best_time_next = best_time;
    best_sym_next = best_sym;
    min_time_next = min_time;
    result_sym_next = result_sym;
    done_next = done;

    case (state)
      S_IDLE: begin
        if (start) begin
          // Initialize DP diagonal and symbols
          dp <= '{default:16'h0};
          for (int ii = 0; ii < 8; ii = ii + 1) begin
            sym[ii][ii] = seq[ii];
          end
          l_next = 4'd2;
          i_next = 4'd0;
          k_next = 4'd0;
          has_best_next = 1'b0;
          best_time_next = 16'hFFFF;
          best_sym_next = 3'd0;
          next_state = S_L_PREP;
        end else begin
          // Idle: clear outputs
          dp <= '{default:16'h0};
          sym <= '{default:3'd0};
          min_time_next = 16'h0;
          result_sym_next = 3'd0;
          done_next = 1'b0;
        end
      end

      S_L_PREP: begin
        if (l_cnt > seq_len) begin
          // Done: output final result
          min_time_next = dp[0][seq_len-1];
          result_sym_next = sym[0][seq_len-1];
          done_next = 1'b1;
          next_state = S_DONE;
        end else begin
          // Prepare for new length: check if we have any i to process
          i_next = 4'd0;
          k_next = 4'd0;
          has_best_next = 1'b0;
          best_time_next = 16'hFFFF;
          best_sym_next = 3'd0;
          next_state = S_I_PREP;
        end
      end

      S_I_PREP: begin
        // j = i + l - 1
        j = i_cnt + l_cnt - 1;
        if (i_cnt <= (seq_len - l_cnt)) begin
          // Valid (i,j): start split loop
          k_next = i_cnt; // start at k = i
          has_best_next = 1'b0;
          best_time_next = 16'hFFFF;
          best_sym_next = 3'd0;
          next_state = S_K_LOOP;
        end else begin
          // Finished all i for this l
          l_next = l_cnt + 1;
          next_state = S_L_PREP;
        end
      end

      S_K_LOOP: begin
        j = i_cnt + l_cnt - 1;
        if (total_time < best_time_next) begin
          best_time_next = total_time;
          best_sym_next = right_is_min ? right_sym : left_sym;
          has_best_next = 1'b1;
        end
        if (k_cnt < (j - 1)) begin
          k_next = k_cnt + 1;
          next_state = S_K_LOOP;
        end else begin
          next_state = S_UPDATE;
        end
      end

      S_UPDATE: begin
        j = i_cnt + l_cnt - 1;
        dp[i_cnt[2:0]][j[2:0]] = has_best_next ? best_time_next : 16'h0;
        sym[i_cnt[2:0]][j[2:0]] = has_best_next ? best_sym_next : seq[i_cnt[2:0]];
        if ((i_cnt + 1) <= (seq_len - l_cnt)) begin
          i_next = i_cnt + 1;
          next_state = S_I_PREP;
        end else begin
          l_next = l_cnt + 1;
          next_state = S_L_PREP;
        end
      end

      S_DONE: begin
        // Hold outputs; wait for start to run again or stay done
        done_next = 1'b1;
        if (start) begin
          // Re-run with same inputs
          dp <= '{default:16'h0};
          for (int ii = 0; ii < 8; ii = ii + 1) sym[ii][ii] = seq[ii];
          l_next = 4'd2;
          i_next = 4'd0;
          k_next = 4'd0;
          has_best_next = 1'b0;
          best_time_next = 16'hFFFF;
          best_sym_next = 3'd0;
          done_next = 1'b0;
          next_state = S_L_PREP;
        end else begin
          next_state = S_DONE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end
endmodule
