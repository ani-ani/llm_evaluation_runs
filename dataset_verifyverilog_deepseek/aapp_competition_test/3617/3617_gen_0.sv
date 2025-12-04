module pikeman(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [15:0] T,
  input [6:0] A,
  input [6:0] B,
  input [6:0] C,
  input [6:0] t0,
  output reg [3:0] num_problems,
  output reg [29:0] penalty,
  output reg done
);

  localparam [2:0] IDLE = 3'd0,
                   GENERATE = 3'd1,
                   SORT = 3'd2,
                   ACCUMULATE = 3'd3,
                   DONE = 3'd4;

  reg [2:0] state, next_state;
  reg [6:0] t [0:7];
  reg [3:0] gen_idx;
  reg [2:0] pass, j;
  reg [3:0] accum_idx;
  reg [15:0] current_time;
  reg [29:0] penalty_sum;
  reg [29:0] next_pen;
  reg [3:0] next_num;
  reg [15:0] time_plus_ti;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      num_problems <= 4'd0;
      penalty <= 30'd0;
      gen_idx <= 4'd0;
      pass <= 3'd0;
      j <= 3'd0;
      accum_idx <= 4'd0;
      current_time <= 16'd0;
      penalty_sum <= 30'd0;
      for (int i=0; i<8; i++) t[i] <= 7'd127;
    end else begin
      state <= next_state;
      case (next_state)
        IDLE: done <= 1'b0;
        GENERATE: begin
          if (gen_idx == 0) t[0] <= t0;
          else t[gen_idx] <= ((A * t[gen_idx-1] + B) % C) + 1;
          gen_idx <= gen_idx + 1;
        end
        SORT: begin
          if (pass < 7) begin
            if (j < 7 - pass) begin
              if (t[j] > t[j+1]) begin
                t[j] <= t[j+1];
                t[j+1] <= t[j];
              end
              j <= j + 1;
            end else begin
              j <= 0;
              pass <= pass + 1;
            end
          end
        end
        ACCUMULATE: begin
          time_plus_ti <= current_time + t[accum_idx];
          if (time_plus_ti <= T) begin
            current_time <= time_plus_ti;
            penalty_sum <= penalty_sum + time_plus_ti;
            if (penalty_sum >= 30'd1000000007) penalty_sum <= penalty_sum - 30'd1000000007;
            accum_idx <= accum_idx + 1;
            next_num <= next_num + 1;
          end
        end
        DONE: begin
          num_problems <= next_num;
          penalty <= penalty_sum;
          done <= 1'b1;
        end
      endcase
      if (next_state == IDLE) begin
        gen_idx <= 4'd0;
        pass <= 3'd0;
        j <= 3'd0;
        accum_idx <= 4'd0;
        current_time <= 16'd0;
        penalty_sum <= 30'd0;
        next_num <= 4'd0;
      end
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = (start) ? ((N == 0) ? DONE : GENERATE) : IDLE;
      GENERATE: next_state = (gen_idx == N-1) ? SORT : GENERATE;
      SORT: next_state = (pass == 7) ? ACCUMULATE : SORT;
      ACCUMULATE: begin
        if (accum_idx == N || (current_time + t[accum_idx] > T)) next_state = DONE;
        else next_state = ACCUMULATE;
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
endmodule