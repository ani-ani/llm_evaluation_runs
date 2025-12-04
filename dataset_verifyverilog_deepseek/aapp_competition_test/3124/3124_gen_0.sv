module ivana_game (
  input              clk,
  input              rst_n,
  input              start,
  input      [2:0]   n,
  input      [9:0]   nums [0:7],
  output reg [3:0]   win_count,
  output reg         done
);

  reg [2:0] state;
  reg [3:0] count;
  reg [3:0] wins;	
  reg [7:0] is_odd;

  parameter IDLE  = 3'd0;
  parameter INIT  = 3'd1;
  parameter CALC  = 3'd2;
  parameter DONE  = 3'd3;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      win_count <= 0;
      done <= 0;
      count <= 0;
      wins <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
            wins <= 0;
            count <= 0;
            for (int i=0; i<8; i++) is_odd[i] <= nums[i][0];
          end
        end

        INIT: begin
          state <= CALC;
          count <= 0;
        end

        CALC: begin
          if (count < 8) begin
            if (count < n) begin
              // Calculate curr_odd = current start position parity
              reg curr_odd = is_odd[count];
              reg [2:0] remaining_moves = n - 3'd1;
              reg [2:0] opp_moves = (remaining_moves + 1'd1) >> 1;
              reg [2:0] ivana_moves = remaining_moves >> 1;

              // Count available odds excluding current
              reg [2:0] avail_odds = 0;
              for (int j=0; j<8; j++) begin
                if (j != count && j < n) avail_odds += is_odd[j];
              end

              // Opponent takes as many odds as possible
              reg [2:0] opp_taken = (avail_odds >= opp_moves) ? opp_moves : avail_odds;
              reg [2:0] remaining_odds = avail_odds - opp_taken;
              reg [2:0] ivana_taken = (remaining_odds > ivana_moves) ? ivana_moves : remaining_odds;
              reg [3:0] ivana_total = curr_odd + ivana_taken;

              if (ivana_total > opp_taken) wins <= wins + 1;
            end
            count <= count + 1;
          end else begin
            win_count <= wins;
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule