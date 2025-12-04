module flight_scheduler(
  input clk,
  input rst_n,
  input start,
  input [15:0] k_days,
  input [3:0] num_flights,
  input [3:0][15:0] flight_days,
  input [3:0][2:0] flight_from,
  input [3:0][2:0] flight_to,
  input [3:0][31:0] flight_cost,
  output reg [31:0] min_cost,
  output reg done,
  output reg impossible
);
  
  enum logic [1:0] {IDLE, PROCESSING, DONE} state;
  reg [4:0] cycle_cnt;
  reg [31:0] arrival_cost [4:1];
  reg [15:0] arrival_day [4:1];
  reg arrival_valid [4:1];
  reg [31:0] departure_cost [4:1];
  reg [15:0] departure_day [4:1];
  reg departure_valid [4:1];
  reg tmp_impossible;
  reg [31:0] tmp_min_cost;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      min_cost <= 32'b0;
      cycle_cnt <= 5'b0;
      for (int i=1; i<=4; i++) begin
        arrival_valid[i] <= 1'b0;
        departure_valid[i] <= 1'b0;
        arrival_cost[i] <= 32'hFFFFFFFF;
        arrival_day[i] <= 16'hFFFF;
        departure_cost[i] <= 32'hFFFFFFFF;
        departure_day[i] <= 16'h0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          impossible <= 1'b0;
          min_cost <= 32'b0;
          if (start) begin
            state <= PROCESSING;
            cycle_cnt <= 5'b0;
            for (int i=1; i<=4; i++) begin
              arrival_valid[i] <= 1'b0;
              departure_valid[i] <= 1'b0;
              arrival_cost[i] <= 32'hFFFFFFFF;
              arrival_day[i] <= 16'hFFFF;
              departure_cost[i] <= 32'hFFFFFFFF;
              departure_day[i] <= 16'h0;
            end
          end
        end
        
        PROCESSING: begin
          if (cycle_cnt < 16) begin
            if (cycle_cnt[3:0] < num_flights) begin
              if (flight_to[cycle_cnt[3:0]] == 3'b0) begin
                if (flight_from[cycle_cnt[3:0]] >= 3'b001 && flight_from[cycle_cnt[3:0]] <= 3'b100) begin
                  automatic int c = flight_from[cycle_cnt[3:0]];
                  if (!arrival_valid[c] || 
                      flight_days[cycle_cnt[3:0]] < arrival_day[c] || 
                      (flight_days[cycle_cnt[3:0]] == arrival_day[c] && flight_cost[cycle_cnt[3:0]] < arrival_cost[c])) begin
                    arrival_valid[c] <= 1'b1;
                    arrival_day[c] <= flight_days[cycle_cnt[3:0]];
                    arrival_cost[c] <= flight_cost[cycle_cnt[3:0]];
                  end
                end
              end
            end
          end else begin
            if (cycle_cnt[3:0] < num_flights) begin
              if (flight_from[cycle_cnt[3:0]] == 3'b0) begin
                if (flight_to[cycle_cnt[3:0]] >= 3'b001 && flight_to[cycle_cnt[3:0]] <= 3'b100) begin
                  automatic int c = flight_to[cycle_cnt[3:0]];
                  if (!departure_valid[c] || 
                      flight_days[cycle_cnt[3:0]] > departure_day[c] || 
                      (flight_days[cycle_cnt[3:0]] == departure_day[c] && flight_cost[cycle_cnt[3:0]] < departure_cost[c])) begin
                    departure_valid[c] <= 1'b1;
                    departure_day[c] <= flight_days[cycle_cnt[3:0]];
                    departure_cost[c] <= flight_cost[cycle_cnt[3:0]];
                  end
                end
              end
            end
          end
          
          if (cycle_cnt == 5'd31) begin
            tmp_impossible = 1'b0;
            tmp_min_cost = 32'b0;
            for (int i=1; i<=4; i++) begin
              if (!arrival_valid[i] || !departure_valid[i] || departure_day[i] < (arrival_day[i] + k_days + 1)) begin
                tmp_impossible = 1'b1;
              end
              tmp_min_cost = tmp_min_cost + arrival_cost[i] + departure_cost[i];
            end
            impossible <= tmp_impossible;
            min_cost <= tmp_impossible ? 32'b0 : tmp_min_cost;
            done <= 1'b1;
            state <= DONE;
          end else begin
            cycle_cnt <= cycle_cnt + 1;
          end
        end
        
        DONE: begin
          done <= 1'b0;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule