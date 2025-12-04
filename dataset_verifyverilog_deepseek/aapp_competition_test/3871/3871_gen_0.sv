module max_profit_calculator (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_candidates,
  input [3:0] l_i [0:7],
  input signed [15:0] s_i [0:7],
  input signed [15:0] c_v [0:15],
  output reg signed [31:0] max_profit,
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, PROCESS, FINISH, DONE} state_t;
  state_t curr_state, next_state;

  reg [3:0] l_i_reg [0:7];
  reg signed [15:0] s_i_reg [0:7];
  reg signed [15:0] c_v_reg [0:15];
  reg [2:0] num_candidates_reg;
  reg [2:0] candidate_idx;

  reg signed [31:0] dp_curr [0:15][0:8];
  reg signed [31:0] dp_next_cmb [0:15][0:8];
  reg signed [31:0] max_profit_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      curr_state <= IDLE;
      done <= 1'b0;
      max_profit <= 0;

      for (int i=0; i<16; i++) begin
        for (int j=0; j<9; j++) begin
          dp_curr[i][j] <= 32'h80000000;
        end
      end
    end else begin
      curr_state <= next_state;

      case (curr_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            num_candidates_reg <= num_candidates;
            for (int i=0; i<8; i++) begin
              l_i_reg[i] <= l_i[i];
              s_i_reg[i] <= s_i[i];
            end
            for (int i=0; i<16; i++) begin
              c_v_reg[i] <= c_v[i];
            end
            next_state <= INIT;
          end
        end

        INIT: begin
          for (int i=0; i<16; i++) begin
            for (int j=0; j<9; j++) begin
              dp_curr[i][j] <= (i==0 && j==0) ? 0 : 32'h80000000;
            end
          end
          candidate_idx <= num_candidates_reg - 1;
          next_state <= PROCESS;
        end

        PROCESS: begin
          candidate_idx <= candidate_idx - 1;
          for (int i=0; i<16; i++) begin
            for (int j=0; j<9; j++) begin
              dp_curr[i][j] <= dp_next_cmb[i][j];
            end
          end
          if (candidate_idx == 0) begin
            next_state <= FINISH;
          end
        end

        FINISH: begin
          max_profit <= max_profit_reg;
          done <= 1'b1;
          next_state <= DONE;
        end

        DONE: ;
      endcase
    end
  end

  always_comb begin
    for (int i=0; i<16; i++) begin
      for (int j=0; j<9; j++) begin
        dp_next_cmb[i][j] = 32'h80000000;
      end
    end

    if (curr_state == PROCESS) begin
      for (int k=0; k<16; k++) begin
        for (int cnt=0; cnt<9; cnt++) begin
          if (dp_curr[k][cnt] != 32'h80000000) begin
            // Skip candidate
            if (dp_curr[k][cnt] > dp_next_cmb[k][cnt]) begin
              dp_next_cmb[k][cnt] = dp_curr[k][cnt];
            end

            // Take candidate
            if (l_i_reg[candidate_idx] > k) begin
              if (dp_curr[k][cnt] + $signed(c_v_reg[l_i_reg[candidate_idx]]) - $signed(s_i_reg[candidate_idx]) > dp_next_cmb[l_i_reg[candidate_idx]][1]) begin
                dp_next_cmb[l_i_reg[candidate_idx]][1] = dp_curr[k][cnt] + $signed(c_v_reg[l_i_reg[candidate_idx]]) - $signed(s_i_reg[candidate_idx]);
              end
            end else if (l_i_reg[candidate_idx] == k && k < 15) begin
              if (cnt >= 1) begin
                if (dp_curr[k][cnt] + ($signed(c_v_reg[k]) * cnt) - $signed(s_i_reg[candidate_idx]) > dp_next_cmb[k+1][1]) begin
                  dp_next_cmb[k+1][1] = dp_curr[k][cnt] + ($signed(c_v_reg[k]) * cnt) - $signed(s_i_reg[candidate_idx]);
                end
              end
            end else if (l_i_reg[candidate_idx] < k) begin
              if (dp_curr[k][cnt] - $signed(s_i_reg[candidate_idx]) > dp_next_cmb[k][cnt]) begin
                dp_next_cmb[k][cnt] = dp_curr[k][cnt] - $signed(s_i_reg[candidate_idx]);
              end
            end
          end
        end
      end
    end else if (curr_state == INIT) begin
      dp_next_cmb[0][0] = 0;
    end
  end

  always_comb begin
    max_profit_reg = 32'h80000000;
    if (curr_state == FINISH || curr_state == DONE) begin
      for (int i=0; i<16; i++) begin
        for (int j=0; j<9; j++) begin
          if (dp_curr[i][j] > max_profit_reg) begin
            max_profit_reg = dp_curr[i][j];
          end
        end
      end
    end
  end

  always_comb begin
    case (curr_state)
      IDLE: next_state = (start) ? INIT : IDLE;
      INIT: next_state = PROCESS;
      PROCESS: next_state = (candidate_idx == 0) ? FINISH : PROCESS;
      FINISH: next_state = DONE;
      DONE: next_state = DONE;
      default: next_state = IDLE;
    endcase
  end

endmodule