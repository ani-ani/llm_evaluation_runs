module min_cost_gather #(
    parameter N = 2,
    parameter MAX_FLIGHTS = 8,
    parameter MAX_DAY = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [28*MAX_FLIGHTS-1:0] flights,
    output reg [19:0] min_cost,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_ARRIVALS = 3'd1;
    localparam [2:0] PROCESS_ARRIVALS = 3'd2;
    localparam [2:0] INIT_DEPARTURES = 3'd3;
    localparam [2:0] PROCESS_DEPARTURES = 3'd4;
    localparam [2:0] COMPUTE_MIN = 3'd5;
    localparam [2:0] FINISHED = 3'd6;

    reg [2:0] state;
    reg [4:0] day_counter;
    reg [3:0] flight_counter;
    reg [19:0] arrival_cost_per_city [1:N];
    reg [19:0] departure_cost_per_city [1:N];
    reg [19:0] arrival_cost [1:MAX_DAY];
    reg [19:0] departure_cost [1:MAX_DAY];
    reg [19:0] total_arrival_cost;
    reg [19:0] total_departure_cost;
    reg [3:0] arrival_count;
    reg [3:0] departure_count;
    reg [19:0] best_cost;
    reg [4:0] compute_day;

    wire flight_valid [0:MAX_FLIGHTS-1];
    wire [4:0] flight_day [0:MAX_FLIGHTS-1];
    wire [2:0] flight_from [0:MAX_FLIGHTS-1];
    wire [2:0] flight_to [0:MAX_FLIGHTS-1];
    wire [15:0] flight_cost [0:MAX_FLIGHTS-1];

    integer i;
    always @(*) begin
        for (i = 0; i < MAX_FLIGHTS; i = i + 1) begin
            flight_valid[i] = flights[i*28 + 27];
            flight_day[i] = flights[i*28 + 26: i*28 + 22];
            flight_from[i] = flights[i*28 + 21: i*28 + 19];
            flight_to[i] = flights[i*28 + 18: i*28 + 16];
            flight_cost[i] = flights[i*28 + 15: i*28];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_cost <= 20'd0;
            day_counter <= 5'd0;
            flight_counter <= 4'd0;
            total_arrival_cost <= 20'd0;
            total_departure_cost <= 20'd0;
            arrival_count <= 4'd0;
            departure_count <= 4'd0;
            best_cost <= 20'd0;
            compute_day <= 5'd0;
            for (i = 1; i <= N; i = i + 1) begin
                arrival_cost_per_city[i] <= 20'd0;
                departure_cost_per_city[i] <= 20'd0;
            end
            for (i = 1; i <= MAX_DAY; i = i + 1) begin
                arrival_cost[i] <= 20'd0;
                departure_cost[i] <= 20'd0;
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
                    for (i = 1; i <= N; i = i + 1) begin
                        arrival_cost_per_city[i] <= 20'hFFFFF;
                    end
                    day_counter <= 5'd1;
                    flight_counter <= 4'd0;
                    state <= PROCESS_ARRIVALS;
                end

                PROCESS_ARRIVALS: begin
                    if (flight_counter < MAX_FLIGHTS) begin
                        if (flight_valid[flight_counter] && flight_to[flight_counter] == 3'd0 && flight_day[flight_counter] == day_counter) begin
                            if (flight_from[flight_counter] >= 1 && flight_from[flight_counter] <= N) begin
                                if (arrival_cost_per_city[flight_from[flight_counter]] > {4'b0, flight_cost[flight_counter]}) begin
                                    if (arrival_cost_per_city[flight_from[flight_counter]] == 20'hFFFFF) begin
                                        arrival_count <= arrival_count + 4'd1;
                                    end
                                    total_arrival_cost <= total_arrival_cost - arrival_cost_per_city[flight_from[flight_counter]] + {4'b0, flight_cost[flight_counter]};
                                    arrival_cost_per_city[flight_from[flight_counter]] <= {4'b0, flight_cost[flight_counter]};
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
                    for (i = 1; i <= N; i = i + 1) begin
                        departure_cost_per_city[i] <= 20'hFFFFF;
                    end
                    day_counter <= MAX_DAY;
                    flight_counter <= 4'd0;
                    state <= PROCESS_DEPARTURES;
                end

                PROCESS_DEPARTURES: begin
                    if (flight_counter < MAX_FLIGHTS) begin
                        if (flight_valid[flight_counter] && flight_from[flight_counter] == 3'd0 && flight_day[flight_counter] == day_counter) begin
                            if (flight_to[flight_counter] >= 1 && flight_to[flight_counter] <= N) begin
                                if (departure_cost_per_city[flight_to[flight_counter]] > {4'b0, flight_cost[flight_counter]}) begin
                                    if (departure_cost_per_city[flight_to[flight_counter]] == 20'hFFFFF) begin
                                        departure_count <= departure_count + 4'd1;
                                    end
                                    total_departure_cost <= total_departure_cost - departure_cost_per_city[flight_to[flight_counter]] + {4'b0, flight_cost[flight_counter]};
                                    departure_cost_per_city[flight_to[flight_counter]] <= {4'b0, flight_cost[flight_counter]};
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
                        if (day_counter > 1) begin
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
                    if (compute_day <= MAX_DAY - 5'd1) begin
                        if (arrival_cost[compute_day] != 20'hFFFFF && departure_cost[compute_day + 5'd1] != 20'hFFFFF) begin
                            if (arrival_cost[compute_day] + departure_cost[compute_day + 5'd1] < best_cost) begin
                                best_cost <= arrival_cost[compute_day] + departure_cost[compute_day + 5'd1];
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