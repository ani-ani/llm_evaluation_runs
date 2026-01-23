module gas_trip_optimizer(input clk, input rst_n, input start, input [2:0] num_stations, input [11:0] station_dist [0:7], input [31:0] station_cost [0:7], input [7:0] tank_capacity, output reg [31:0] total_cost, output reg done, output reg cancel);
reg [2:0] state, state_next;
reg [2:0] current_station, current_station_next;
reg [7:0] current_fuel, current_fuel_next;
reg [11:0] current_position, current_position_next;
reg [31:0] total_cost_reg, total_cost_reg_next;
reg [2:0] next_target_station, next_target_station_next;
reg done_next, cancel_next;
always @(posedge clk or negedge rst_n) begin if (!rst_n) begin state <= 0; current_station <= 0; current_fuel <= 0; current_position <= 0; total_cost_reg <= 0; done_next <= 0; cancel_next <= 0; end else begin state <= state_next; current_station <= current_station_next; current_fuel <= current_fuel_next; current_position <= current_position_next; total_cost_reg <= total_cost_reg_next; done_next <= done_next; cancel_next <= cancel_next; end end
always @(*) begin state_next = state; current_station_next = current_station; current_fuel_next = current_fuel; current_position_next = current_position; total_cost_reg_next = total_cost_reg; done_next = 0; cancel_next = 0; case (state) 0: begin if (start) begin state_next = 1; current_station_next = 0; current_fuel_next = tank_capacity; current_position_next = station_dist[0]; end end 1: begin if (station_dist[0] > tank_capacity) begin state_next = 6; cancel_next = 1; done_next = 1; end else begin state_next = 2; end end 2: begin state_next = 3; end 3: begin state_next = 4; end 4: begin state_next = 2; end 5: begin end 6: begin end default: state_next =0; endcase end
assign total_cost = total_cost_reg;
assign done = done_next;
assign cancel = cancel_next;
endmodule