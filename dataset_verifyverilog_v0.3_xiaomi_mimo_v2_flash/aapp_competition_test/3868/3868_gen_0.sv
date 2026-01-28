module min_cost_gather #(
    parameter N = 2,           // Number of cities (1 to N)
    parameter MAX_FLIGHTS = 8, // Maximum number of flights
    parameter MAX_DAY = 16     // Maximum day value
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] k,          // Window size parameter
    input wire [28*MAX_FLIGHTS-1:0] flights,
    output reg [19:0] min_cost,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT_ARRIVALS = 3'd1;
localparam [2:0] PROCESS_ARRIVALS = 3'd2;
localparam [2:0] INIT_DEPARTURES = 3'd3;
localparam [2:0] PROCESS_DEPARTURES = 3'd4;
localparam [2:0] COMPUTE_MIN = 3'd5;
localparam [2:0] FINISHED = 3'd6;

// Internal signals and registers
reg [2:0] state;
reg [4:0] day_counter;
reg [3:0] flight_counter;
reg [4:0] compute_day;
reg [19:0] best_cost;

// Cost storage arrays (using packed format for synthesis compatibility)
reg [19:0] arrival_cost [1:MAX_DAY];
reg [19:0] departure_cost [1:MAX_DAY];

// Per-city temporary storage
reg [19:0] arrival_cost_per_city [1:16];  // Max N=16
reg [19:0] departure_cost_per_city [1:16];
reg [3:0] arrival_count;
reg [3:0] departure_count;
reg [19:0] total_arrival_cost;
reg [19:0] total_departure_cost;

// Flight unpacking
wire flight_valid [0:MAX_FLIGHTS-1];
wire [4:0] flight_day [0:MAX_FLIGHTS-1];
wire [2:0] flight_from [0:MAX_FLIGHTS-1];
wire [2:0] flight_to [0:MAX_FLIGHTS-1];
wire [15:0] flight_cost [0:MAX_FLIGHTS-1];

// Unpack flights - no generate, assign individually
assign flight_valid[0] = flights[27];
assign flight_day[0] = flights[26:22];
assign flight_from[0] = flights[21:19];
assign flight_to[0] = flights[18:16];
assign flight_cost[0] = flights[15:0];

assign flight_valid[1] = flights[55];
assign flight_day[1] = flights[54:50];
assign flight_from[1] = flights[49:47];
assign flight_to[1] = flights[46:44];
assign flight_cost[1] = flights[43:28];

assign flight_valid[2] = flights[83];
assign flight_day[2] = flights[82:78];
assign flight_from[2] = flights[77:75];
assign flight_to[2] = flights[74:72];
assign flight_cost[2] = flights[71:56];

assign flight_valid[3] = flights[111];
assign flight_day[3] = flights[110:106];
assign flight_from[3] = flights[105:103];
assign flight_to[3] = flights[102:100];
assign flight_cost[3] = flights[99:84];

assign flight_valid[4] = flights[139];
assign flight_day[4] = flights[138:134];
assign flight_from[4] = flights[133:131];
assign flight_to[4] = flights[130:128];
assign flight_cost[4] = flights[127:112];

assign flight_valid[5] = flights[167];
assign flight_day[5] = flights[166:162];
assign flight_from[5] = flights[161:159];
assign flight_to[5] = flights[158:156];
assign flight_cost[5] = flights[155:140];

assign flight_valid[6] = flights[195];
assign flight_day[6] = flights[194:190];
assign flight_from[6] = flights[189:187];
assign flight_to[6] = flights[186:184];
assign flight_cost[6] = flights[183:168];

assign flight_valid[7] = flights[223];
assign flight_day[7] = flights[222:218];
assign flight_from[7] = flights[217:215];
assign flight_to[7] = flights[214:212];
assign flight_cost[7] = flights[211:196];

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        min_cost <= 20'hFFFFF;
        day_counter <= 5'd0;
        flight_counter <= 4'd0;
        compute_day <= 5'd0;
        best_cost <= 20'hFFFFF;
        arrival_count <= 4'd0;
        departure_count <= 4'd0;
        total_arrival_cost <= 20'd0;
        total_departure_cost <= 20'd0;
        // Initialize arrays
        begin : init_arrays
            integer i;
            for (i = 1; i <= MAX_DAY; i = i + 1) begin
                arrival_cost[i] <= 20'hFFFFF;
                departure_cost[i] <= 20'hFFFFF;
            end
            for (i = 1; i <= 16; i = i + 1) begin
                arrival_cost_per_city[i] <= 20'hFFFFF;
                departure_cost_per_city[i] <= 20'hFFFFF;
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT_ARRIVALS;
                end
            end

            INIT_ARRIVALS: begin
                arrival_count <= 4'd0;
                total_arrival_cost <= 20'd0;
                begin : init_arrivals_loop
                    integer j;
                    for (j = 1; j <= 16; j = j + 1) begin
                        arrival_cost_per_city[j] <= 20'hFFFFF;
                    end
                end
                day_counter <= 5'd1;
                flight_counter <= 4'd0;
                state <= PROCESS_ARRIVALS;
            end

            PROCESS_ARRIVALS: begin
                if (flight_counter < MAX_FLIGHTS) begin
                    if (flight_valid[flight_counter] && flight_to[flight_counter] == 3'd0 && flight_day[flight_counter] == day_counter) begin
                        if (flight_from[flight_counter] >= 3'd1 && flight_from[flight_counter] <= 3'd4 && N >= 1 && flight_from[flight_counter] <= N) begin
                            reg [3:0] city_idx;
                            reg [19:0] new_cost;
                            city_idx = {1'b0, flight_from[flight_counter]};
                            new_cost = {4'd0, flight_cost[flight_counter]};
                            if (arrival_cost_per_city[city_idx] > new_cost) begin
                                if (arrival_cost_per_city[city_idx] == 20'hFFFFF) begin
                                    arrival_count <= arrival_count + 4'd1;
                                end
                                total_arrival_cost <= total_arrival_cost - arrival_cost_per_city[city_idx] + new_cost;
                                arrival_cost_per_city[city_idx] <= new_cost;
                            end
                        end
                    end
                    flight_counter <= flight_counter + 4'd1;
                end else begin
                    if (arrival_count == N) begin
                        arrival_cost[day_counter] <= total_arrival_cost;
                    end else begin
                        arrival_cost[day_counter] <= 20'hFFFFF;
                    end
                    if (day_counter < MAX_DAY) begin
                        day_counter <= day_counter + 5'd1;
                        flight_counter <= 4'd0;
                    end else begin
                        state <= INIT_DEPARTURES;
                    end
                end
            end

            INIT_DEPARTURES: begin
                departure_count <= 4'd0;
                total_departure_cost <= 20'd0;
                begin : init_departures_loop
                    integer j;
                    for (j = 1; j <= 16; j = j + 1) begin
                        departure_cost_per_city[j] <= 20'hFFFFF;
                    end
                end
                day_counter <= MAX_DAY;
                flight_counter <= 4'd0;
                state <= PROCESS_DEPARTURES;
            end

            PROCESS_DEPARTURES: begin
                if (flight_counter < MAX_FLIGHTS) begin
                    if (flight_valid[flight_counter] && flight_from[flight_counter] == 3'd0 && flight_day[flight_counter] == day_counter) begin
                        if (flight_to[flight_counter] >= 3'd1 && flight_to[flight_counter] <= 3'd4 && N >= 1 && flight_to[flight_counter] <= N) begin
                            reg [3:0] city_idx;
                            reg [19:0] new_cost;
                            city_idx = {1'b0, flight_to[flight_counter]};
                            new_cost = {4'd0, flight_cost[flight_counter]};
                            if (departure_cost_per_city[city_idx] > new_cost) begin
                                if (departure_cost_per_city[city_idx] == 20'hFFFFF) begin
                                    departure_count <= departure_count + 4'd1;
                                end
                                total_departure_cost <= total_departure_cost - departure_cost_per_city[city_idx] + new_cost;
                                departure_cost_per_city[city_idx] <= new_cost;
                            end
                        end
                    end
                    flight_counter <= flight_counter + 4'd1;
                end else begin
                    if (departure_count == N) begin
                        departure_cost[day_counter] <= total_departure_cost;
                    end else begin
                        departure_cost[day_counter] <= 20'hFFFFF;
                    end
                    if (day_counter > 5'd1) begin
                        day_counter <= day_counter - 5'd1;
                        flight_counter <= 4'd0;
                    end else begin
                        state <= COMPUTE_MIN;
                        compute_day <= 5'd1;
                        best_cost <= 20'hFFFFF;
                    end
                end
            end

            COMPUTE_MIN: begin
                if (compute_day + k <= MAX_DAY) begin
                    if (arrival_cost[compute_day] != 20'hFFFFF && departure_cost[compute_day + k] != 20'hFFFFF) begin
                        reg [19:0] total_cost;
                        total_cost = arrival_cost[compute_day] + departure_cost[compute_day + k];
                        if (total_cost < best_cost) begin
                            best_cost <= total_cost;
                        end
                    end
                    compute_day <= compute_day + 5'd1;
                end else begin
                    state <= FINISHED;
                    if (best_cost != 20'hFFFFF) begin
                        min_cost <= best_cost;
                    end else begin
                        min_cost <= 20'hFFFFF;
                    end
                end
            end

            FINISHED: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule