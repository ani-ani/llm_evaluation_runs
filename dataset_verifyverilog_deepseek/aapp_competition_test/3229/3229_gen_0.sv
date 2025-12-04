module worst_rank_calculator(
  input clk,
  input rst_n,
  input [3:0] num_contestants,
  input [3:0] num_contests,
  input [6:0] scores [0:3][0:3],
  output reg [2:0] worst_rank,
  output reg done
);
  
  reg [3:0] num_contestants_reg;
  reg [3:0] num_contests_reg;
  reg [6:0] scores_reg [0:3][0:3];
  reg [8:0] current_agg [0:3];
  reg [8:0] final_agg [0:3];
  reg [2:0] state;
  
  localparam IDLE        = 3'd0,
             CALC_AGG    = 3'd1,
             FINAL_AGG   = 3'd2,
             COMP_RANK   = 3'd3,
             DONE        = 3'd4;
  
  function automatic [8:0] sum_scores;
    input [6:0] scores_arr [0:3];
    input [3:0] num;
    begin
      sum_scores = 0;
      for (int j = 0; j < num; j++) begin
        sum_scores = sum_scores + {2'b0, scores_arr[j]};
      end
    end
  endfunction
  
  always_ff @(posedge clk) begin
    if (~rst_n) begin
      done <= 0;
      worst_rank <= 0;
      state <= IDLE;
      num_contestants_reg <= 0;
      num_contests_reg <= 0;
      for (int i = 0; i < 4; i++) begin
        current_agg[i] <= 0;
        final_agg[i] <= 0;
        for (int j = 0; j < 4; j++) begin
          scores_reg[i][j] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          num_contestants_reg <= num_contestants;
          num_contests_reg <= num_contests;
          for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
              scores_reg[i][j] <= scores[i][j];
            end
          end
          state <= CALC_AGG;
        end
        
        CALC_AGG: begin
          for (int i = 0; i < 4; i++) begin
            current_agg[i] <= sum_scores(scores_reg[i], num_contests_reg);
          end
          state <= FINAL_AGG;
        end
        
        FINAL_AGG: begin
          final_agg[0] <= current_agg[0];
          for (int i = 1; i < 4; i++) begin
            if (i < num_contestants_reg) begin
              final_agg[i] <= current_agg[i] + 9'd101;
            end else begin
              final_agg[i] <= 0;
            end
          end
          state <= COMP_RANK;
        end
        
        COMP_RANK: begin
          worst_rank <= 1;
          for (int i = 1; i < num_contestants_reg; i++) begin
            if (final_agg[i] > final_agg[0]) begin
              worst_rank <= worst_rank + 1;
            end
          end
          done <= 1;
          state <= DONE;
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end
endmodule