module train_refund_eligibility(
  input clk,  // clock signal
  input rst_n,  // active-low reset
  input start,  // start computation
  input [1:0] num_stations,  // N (2-4 stations)
  input [1:0] num_trains,  // M (1-4 trains)
  input [1:0] train_station [3:0],  // [M-1:0] X (starting station)
  input [16:0] train_depart [3:0],  // [M-1:0] S (planned departure)
  input [16:0] train_arrive [3:0],  // [M-1:0] T (planned arrival)
  input [16:0] train_delay [3:0],  // [M-1:0] L (delay duration)
  output reg [16:0] result,  // earliest valid start time (131071=impossible)
  output reg done  // high when computation complete
);

  typedef enum logic [2:0] {IDLE, LOAD, PROCESS, DONE} state_t;
  state_t state, next_state;
  reg [4:0] cycle_count;
  reg [1:0] loaded_num_stations;
  reg [1:0] loaded_num_trains;
  reg [1:0] loaded_station [3:0];
  reg [16:0] loaded_depart [3:0];
  reg [16:0] loaded_arrive [3:0];
  reg [16:0] loaded_delay [3:0];
  reg [16:0] candidate_result;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 131071;
      done <= 0;
      cycle_count <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= LOAD;
            cycle_count <= 0;
          end
        end

        LOAD: begin
          loaded_num_stations <= num_stations;
          loaded_num_trains <= num_trains;
          for (int i=0; i<4; i++) begin
            loaded_station[i] <= train_station[i];
            loaded_depart[i] <= train_depart[i];
            loaded_arrive[i] <= train_arrive[i];
            loaded_delay[i] <= train_delay[i];
          end
          state <= PROCESS;
        end

        PROCESS: begin
          cycle_count <= cycle_count + 1;
          if (cycle_count == (8 + 2*loaded_num_trains - 1))
            state <= DONE;
          else
            state <= PROCESS;
        end

        DONE: begin
          result <= candidate_result;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

  always_comb begin
    reg [16:0] max_min_s = 0;
    int valid_path = 0;
    int k = loaded_num_stations - 1;
    candidate_result = 131071;

    if (state == PROCESS) begin
      if (k == 1) begin
        for (int t0=0; t0<4; t0++) begin
          if (t0 < loaded_num_trains && loaded_station[t0] == 1) begin
            int min_s = (1800 - loaded_delay[t0] + 0 + 0) / 1;
            if (min_s > max_min_s) max_min_s = min_s;
            valid_path = 1;
          end
        end
      end
      else if (k == 2) begin
        for (int t0=0; t0<4; t0++) begin
          if (t0 < loaded_num_trains && loaded_station[t0] == 1) begin
            for (int t1=0; t1<4; t1++) begin
              if (t1 < loaded_num_trains && loaded_station[t1] == 2) begin
                int t_sum = loaded_arrive[t0];
                int min_s = (1800 - loaded_delay[t1] + t_sum + 1) / 2;
                if (min_s > max_min_s) max_min_s = min_s;
                valid_path = 1;
              end
            end
          end
        end
      end
      else if (k == 3) begin
        for (int t0=0; t0<4; t0++) begin
          if (t0 < loaded_num_trains && loaded_station[t0] == 1) begin
            for (int t1=0; t1<4; t1++) begin
              if (t1 < loaded_num_trains && loaded_station[t1] == 2) begin
                for (int t2=0; t2<4; t2++) begin
                  if (t2 < loaded_num_trains && loaded_station[t2] == 3) begin
                    int t_sum = loaded_arrive[t0] + loaded_arrive[t1];
                    int min_s = (1800 - loaded_delay[t2] + t_sum + 2) / 3;
                    if (min_s > max_min_s) max_min_s = min_s;
                    valid_path = 1;
                  end
                end
              end
            end
          end
        end
      end
      if (valid_path) candidate_result = (max_min_s < 0) ? 0 : (max_min_s > 131071) ? 131071 : max_min_s[16:0];
    end
  end

endmodule