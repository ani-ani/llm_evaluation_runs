module domino_tiling_maxsum(
  input clk,
  input rst_n,
  input start,
  input [19:0] row0_col0, row0_col1, row0_col2,
  input [19:0] row1_col0, row1_col1, row1_col2,
  input [19:0] row2_col0, row2_col1, row2_col2,
  input [19:0] row3_col0, row3_col1, row3_col2,
  output reg [23:0] max_sum,
  output reg done
);

  wire signed [19:0] grid[0:3][0:2] = '{'{row0_col0, row0_col1, row0_col2},'{row1_col0, row1_col1, row1_col2},'{row2_col0, row2_col1, row2_col2},'{row3_col0, row3_col1, row3_col2}};

  typedef enum logic [2:0] {IDLE, CALC_ROW0, CALC_ROW1, CALC_ROW2, CALC_ROW3, FINAL, DONE} state_t;
  state_t state, next_state;
  reg [2:0] row;
  reg [3:0] count;

  reg signed [23:0] current_dp[0:2][0:7];
  reg signed [23:0] next_dp[0:2][0:7];

  function void init_dp();
    for (int k=0; k<3; k++) begin
      for (int mask=0; mask<8; mask++) begin
        current_dp[k][mask] = -24'sd999999;
      end
    end
    current_dp[0][0] = 0;
  endfunction

  function bit [2:0] avail(input [2:0] pmask);
    return ~pmask;
  endfunction

  always_comb begin
    for (int k=0; k<3; k++) begin
      for (int mask=0; mask<8; mask++) begin
        next_dp[k][mask] = -24'sd999999;
      end
    end

    for (int pk=0; pk<3; pk++) begin
      for (int pmask=0; pmask<8; pmask++) begin
        if (current_dp[pk][pmask] < -24'sd999998) continue;
        reg [2:0] curr_avail = avail(pmask);
        for (int sv=0; sv<8; sv++) begin
          if ((sv & ~curr_avail) != 0) continue;
          if (row == 3 && sv != 0) continue;
          int v_cnt = $countones(sv);
          if (pk + v_cnt > 2) continue;
          reg [23:0] v_sum = 0;
          for (int j=0; j<3; j++) begin
            if (sv[j]) begin
              v_sum += grid[row][j];
              if (row < 3) v_sum += grid[row + 1][j];
              else v_sum = -24'sd999999;
            end
          end
          if (v_sum < -24'sd999998) continue;
          reg [2:0] remain = curr_avail & ~sv;
          for (int horz=0; horz < 2; horz++) begin
            if ((pk + v_cnt + (horz ? 1 : 0)) > 2) continue;
            reg signed [19:0] h_sum0 = grid[row][0] + grid[row][1];
            reg signed [19:0] h_sum1 = grid[row][1] + grid[row][2];
            reg h_poss0 = (horz == 1) && remain[0] && remain[1];
            reg h_poss1 = (horz == 1) && remain[1] && remain[2];
            if (horz && !h_poss0 && !h_poss1) continue;
            reg signed [23:0] total_add;
            if (horz) total_add = v_sum + (h_poss0 ? h_sum0 : (h_poss1 ? h_sum1 : 0));
            else total_add = v_sum;
            int new_k = pk + v_cnt + (horz ? 1 : 0);
            if (total_add < -24'sd999998) continue;
            reg signed [23:0] new_sum = current_dp[pk][pmask] + total_add;
            reg [2:0] new_mask = (row < 3) ? sv : 0;
            if (new_k > 2) continue;
            if (new_sum > next_dp[new_k][new_mask]) begin
              next_dp[new_k][new_mask] = new_sum;
            end
          end
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      count <= 0;
      max_sum <= 0;
      init_dp();
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            init_dp();
            state <= CALC_ROW0;
            row <= 0;
            count <= 1;
          end
        end
        CALC_ROW0: begin
          current_dp <= next_dp;
          state <= CALC_ROW1;
          row <= 1;
          count <= count + 1;
        end
        CALC_ROW1: begin
          current_dp <= next_dp;
          state <= CALC_ROW2;
          row <= 2;
          count <= count + 1;
        end
        CALC_ROW2: begin
          current_dp <= next_dp;
          state <= CALC_ROW3;
          row <= 3;
          count <= count + 1;
        end
        CALC_ROW3: begin
          current_dp <= next_dp;
          state <= FINAL;
          count <= count + 1;
        end
        FINAL: begin
          max_sum <= current_dp[2][0];
          state <= DONE;
          count <= count + 1;
        end
        DONE: begin
          done <= (count >= 7);
          if (count >= 8) begin
            done <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule