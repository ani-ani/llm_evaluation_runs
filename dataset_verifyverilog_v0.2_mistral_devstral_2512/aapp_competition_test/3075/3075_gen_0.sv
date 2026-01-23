module gas_trip_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_stations,
    input [11:0] station_dist [0:7],
    input [31:0] station_cost [0:7],
    input [7:0] tank_capacity,
    output reg [31:0] total_cost,
    output reg done,
    output reg cancel
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_REACHABLE,
        FIND_CHEAPEST,
        BUY_FUEL,
        NEXT_STATION,
        DONE,
        CANCEL
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] current_station;
    reg [7:0] current_fuel;
    reg [11:0] current_dist;
    reg [2:0] last_idx;
    reg [2:0] cheapest_station;
    reg [31:0] cheapest_cost;
    reg [7:0] fuel_needed;
    reg [11:0] next_dist;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_station <= 0;
            current_fuel <= 0;
            current_dist <= 0;
            last_idx <= 0;
            cheapest_station <= 0;
            cheapest_cost <= 0;
            fuel_needed <= 0;
            next_dist <= 0;
            total_cost <= 0;
            done <= 0;
            cancel <= 0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_station <= 0;
                        current_fuel <= tank_capacity;
                        current_dist <= station_dist[0];
                        total_cost <= 0;
                        done <= 0;
                        cancel <= 0;
                        next_state <= CHECK_REACHABLE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                CHECK_REACHABLE: begin
                    if (current_dist > current_fuel) begin
                        next_state <= CANCEL;
                    end else begin
                        next_state <= FIND_CHEAPEST;
                    end
                end
                
                FIND_CHEAPEST: begin
                    next_state <= BUY_FUEL;
                end
                
                BUY_FUEL: begin
                    next_state <= NEXT_STATION;
                end
                
                NEXT_STATION: begin
                    if (current_station == num_stations - 1) begin
                        next_state <= DONE;
                    end else begin
                        current_station <= current_station + 1;
                        current_dist <= station_dist[current_station];
                        next_state <= CHECK_REACHABLE;
                    end
                end
                
                DONE: begin
                    done <= 1;
                    next_state <= IDLE;
                end
                
                CANCEL: begin
                    cancel <= 1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    // Combinational logic for finding cheapest station within range
    always @(*) begin
        last_idx = 0;
        cheapest_station = 0;
        cheapest_cost = 32'hFFFFFFFF;
        
        for (int i = current_station + 1; i < num_stations; i++) begin
            if (station_dist[i] - current_dist <= current_fuel) begin
                last_idx = i;
                if (station_cost[i] < cheapest_cost) begin
                    cheapest_station = i;
                    cheapest_cost = station_cost[i];
                end
            end
        end
    end

    // Fuel calculation logic
    always @(*) begin
        fuel_needed = 0;
        next_dist = 0;
        
        if (current_state == BUY_FUEL) begin
            if (cheapest_station == 0) begin
                // No cheaper station found, fill tank
                fuel_needed = tank_capacity - current_fuel;
                next_dist = current_dist + tank_capacity;
            end else begin
                // Buy just enough to reach cheapest station
                fuel_needed = station_dist[cheapest_station] - current_dist;
                next_dist = station_dist[cheapest_station];
            end
        end
    end

    // Total cost calculation
    always @(posedge clk) begin
        if (current_state == BUY_FUEL) begin
            total_cost <= total_cost + (station_cost[current_station] * fuel_needed);
            current_fuel <= current_fuel - (next_dist - current_dist) + fuel_needed;
        end
    end

endmodule