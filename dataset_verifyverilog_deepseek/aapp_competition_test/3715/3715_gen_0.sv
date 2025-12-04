module vacation_rest_counter(
  input clk,
  input rst_n,
  input start,
  input [4:0] num_days,
  input [1:0] day_status [0:15],
  output reg [4:0] rest_count,
  output reg done
);

typedef enum logic [1:0] {
  IDLE,
  PROCESS,
  DONE
} state_t;

state_t state;
reg [4:0] day_counter;
reg [4:0] p_rest, p_contest, p_sport;
wire [4:0] n_rest, n_contest, n_sport;
wire [4:0] max_val = 5'b10000;

// Next state DP calculations
assign n_rest = (state == PROCESS && day_counter < num_days) ?
                ((p_rest <= p_contest && p_rest <= p_sport) ? p_rest :
                 (p_contest <= p_sport) ? p_contest : p_sport) + 5'b1 : p_rest;

assign n_contest = (state == PROCESS && day_counter < num_days && day_status[day_counter][0]) ?
                   ((p_rest <= p_sport) ? p_rest : p_sport) : 
                   (state == PROCESS && day_counter < num_days) ? max_val : p_contest;

assign n_sport = (state == PROCESS && day_counter < num_days && day_status[day_counter][1]) ?
                 ((p_rest <= p_contest) ? p_rest : p_contest) : 
                 (state == PROCESS && day_counter < num_days) ? max_val : p_sport;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    rest_count <= 5'b0;
    day_counter <= 5'b0;
    p_rest <= max_val;
    p_contest <= max_val;
    p_sport <= max_val;
  end
  else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        rest_count <= 5'b0;
        if (start) begin
          state <= PROCESS;
          day_counter <= 5'b0;
          p_rest <= max_val;
          p_contest <= max_val;
          p_sport <= max_val;
        end
      end

      PROCESS: begin
        p_rest <= n_rest;
        p_contest <= n_contest;
        p_sport <= n_sport;

        if (day_counter == 5'd15) begin
          state <= DONE;
          rest_count <= (n_rest <= n_contest && n_rest <= n_sport) ? n_rest :
                       (n_contest <= n_sport) ? n_contest : n_sport;
        end
        else begin
          day_counter <= day_counter + 5'b1;
        end
      end

      DONE: begin
        done <= 1'b1;
        if (start) begin
          state <= IDLE;
          done <= 1'b0;
          rest_count <= 5'b0;
        end
      end
    endcase
  end
end
endmodule