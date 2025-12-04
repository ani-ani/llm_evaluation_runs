module cheer_scheduler (
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [2:0] t,
  input [1:0] m,
  input [3:0] interval_0_a, interval_0_b,
  input [3:0] interval_1_a, interval_1_b,
  input [3:0] interval_2_a, interval_2_b,
  output reg [2:0] sportify_goals,
  output reg [2:0] spoilify_goals,
  output reg done
);

  reg [2:0] state;
  localparam IDLE            = 3'd0;
  localparam COMPUTE_OPP     = 3'd1;
  localparam PROCESS_SCHED   = 3'd2;
  localparam UPDATE_BEST     = 3'd3;
  localparam FINISH          = 3'd4;

  reg [2:0] sched_index;
  reg [2:0] best_sportify, best_spoilify;
  reg [2:0] current_sportify, current_spoilify;
  reg [2:0] opponent_count [0:7];
  reg [7:0] sportify_cheer;
  integer i, j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      sched_index <= 0;
      sportify_goals <= 0;
      spoilify_goals <= 0;
      best_sportify <= 0;
      best_spoilify <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= COMPUTE_OPP;
            sched_index <= 0;
            best_sportify <= 0;
            best_spoilify <= 0;
          end
        end

        COMPUTE_OPP: begin
          for (i = 0; i < 8; i = i + 1) begin
            opponent_count[i] = 0;
            if (m > 0 && i >= interval_0_a && i < interval_0_b)
              opponent_count[i]++;
            if (m > 1 && i >= interval_1_a && i < interval_1_b)
              opponent_count[i]++;
            if (m > 2 && i >= interval_2_a && i < interval_2_b)
              opponent_count[i]++;
          end
          state <= PROCESS_SCHED;
        end

        PROCESS_SCHED: begin
          sportify_cheer = 0;
          for (i = 0; i < 8; i = i + 1) begin
            if (i >= sched_index && i < sched_index + 3)
              sportify_cheer[i] = 1;
          end

          current_sportify = 0;
          current_spoilify = 0;

          // First half (minutes 0-3)
          for (j = 0; j < 3; j = j + 1) begin
            if (sportify_cheer[j] > opponent_count[j] && sportify_cheer[j+1] > opponent_count[j+1])
              current_sportify++;
            else if (sportify_cheer[j] < opponent_count[j] && sportify_cheer[j+1] < opponent_count[j+1])
              current_spoilify++;
          end

          // Second half (minutes 4-7)
          for (j = 4; j < 7; j = j + 1) begin
            if (sportify_cheer[j] > opponent_count[j] && sportify_cheer[j+1] > opponent_count[j+1])
              current_sportify++;
            else if (sportify_cheer[j] < opponent_count[j] && sportify_cheer[j+1] < opponent_count[j+1])
              current_spoilify++;
          end

          state <= UPDATE_BEST;
        end

        UPDATE_BEST: begin
          if ((current_sportify > current_spoilify && 
               (current_sportify - current_spoilify) > (best_sportify - best_spoilify)) ||
              ((current_sportify - current_spoilify) == (best_sportify - best_spoilify) &&
               current_sportify > best_sportify)) begin
            best_sportify <= current_sportify;
            best_spoilify <= current_spoilify;
          end

          if (sched_index == 5) begin
            state <= FINISH;
          end else begin
            sched_index <= sched_index + 1;
            state <= PROCESS_SCHED;
          end
        end

        FINISH: begin
          sportify_goals <= best_sportify;
          spoilify_goals <= best_spoilify;
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule