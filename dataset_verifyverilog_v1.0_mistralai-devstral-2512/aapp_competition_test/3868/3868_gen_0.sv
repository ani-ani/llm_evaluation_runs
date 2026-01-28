module MetropolisFlightScheduling(
    input clk,
    input rst_n,
    input start,
    input [8:0] flight_day,
    input [4:0] flight_from,
    input [4:0] flight_to,
    input [15:0] flight_cost,
    input flight_valid,
    input [8:0] k_duration,
    output reg [15:0] min_cost,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] READ_FLIGHTS = 4'd1;
    localparam [3:0] COMPUTE_INCOMING = 4'd2;
    localparam [3:0] COMPUTE_OUTGOING = 4'd3;
    localparam [3:0] FIND_MIN = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;

    // Flight memory (32 flights max)
    reg [8:0] flight_mem_day [0:31];
    reg [4:0] flight_mem_from [0:31];
    reg [4:0] flight_mem_to [0:31];
    reg [15:0] flight_mem_cost [0:31];
    reg [4:0] flight_count;

    // Day cost arrays (256 days, 16 cities)
    reg [15:0] cost_to_metropolis [0:255];
    reg [15:0] cost_from_metropolis [0:255];

    // Loop counters
    reg [7:0] day_counter;
    reg [7:0] city_counter;
    reg [7:0] flight_index;

    // Intermediate results
    reg [15:0] current_cost;
    reg [15:0] temp_cost;
    reg [15:0] arrival_day_cost;
    reg [15:0] departure_day_cost;
    reg [15:0] total_cost;

    // Min cost tracking
    reg [15:0] current_min_cost;
    reg found_solution;

    // Cycle counter for safety
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            min_cost <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            flight_count <= 5'd0;
            day_counter <= 8'd0;
            city_counter <= 8'd0;
            flight_index <= 8'd0;
            current_cost <= 16'd0;
            temp_cost <= 16'd0;
            arrival_day_cost <= 16'd0;
            departure_day_cost <= 16'd0;
            total_cost <= 16'd0;
            current_min_cost <= 16'd0;
            found_solution <= 1'b0;
            cycle_count <= 14'd0;

            // Initialize flight memory
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                flight_mem_day[i] <= 9'd0;
                flight_mem_from[i] <= 5'd0;
                flight_mem_to[i] <= 5'd0;
                flight_mem_cost[i] <= 16'd0;
            end

            // Initialize cost arrays
            for (i = 0; i < 256; i = i + 1) begin
                cost_to_metropolis[i] <= 16'd0;
                cost_from_metropolis[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 14'd1;

            if (cycle_count >= MAX_CYCLES) begin
                next_state <= DONE_STATE;
                impossible <= 1'b1;
            end
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                cycle_count = 14'd0;
                if (start) begin
                    next_state = READ_FLIGHTS;
                end else begin
                    next_state = IDLE;
                end
            end

            READ_FLIGHTS: begin
                if (flight_valid && flight_count < 5'd32) begin
                    // Store flight data
                    flight_mem_day[flight_count] = flight_day;
                    flight_mem_from[flight_count] = flight_from;
                    flight_mem_to[flight_count] = flight_to;
                    flight_mem_cost[flight_count] = flight_cost;
                    flight_count = flight_count + 5'd1;
                end

                if (flight_count >= 5'd32 || !flight_valid) begin
                    next_state = COMPUTE_INCOMING;
                    day_counter = 8'd0;
                    city_counter = 8'd0;
                end else begin
                    next_state = READ_FLIGHTS;
                end
            end

            COMPUTE_INCOMING: begin
                // Initialize cost arrays
                if (day_counter == 8'd0 && city_counter == 8'd0) begin
                    integer i;
                    for (i = 0; i < 256; i = i + 1) begin
                        cost_to_metropolis[i] = 16'd0;
                    end
                end

                // Update cost for current day and city
                if (city_counter < 8'd16) begin
                    // Find minimum cost flight to Metropolis (city 0)
                    temp_cost = 16'd0;
                    for (flight_index = 0; flight_index < flight_count; flight_index = flight_index + 1) begin
                        if (flight_mem_to[flight_index] == 5'd0 && 
                            flight_mem_day[flight_index] == day_counter &&
                            flight_mem_from[flight_index] == city_counter) begin
                            if (temp_cost == 16'd0 || flight_mem_cost[flight_index] < temp_cost) begin
                                temp_cost = flight_mem_cost[flight_index];
                            end
                        end
                    end

                    // If no flight found, keep previous day's cost
                    if (temp_cost != 16'd0) begin
                        cost_to_metropolis[day_counter] = temp_cost;
                    end else if (day_counter > 8'd0) begin
                        cost_to_metropolis[day_counter] = cost_to_metropolis[day_counter - 1];
                    end

                    city_counter = city_counter + 8'd1;
                end else begin
                    city_counter = 8'd0;
                    day_counter = day_counter + 8'd1;

                    if (day_counter >= 8'd256) begin
                        next_state = COMPUTE_OUTGOING;
                        day_counter = 8'd255;
                        city_counter = 8'd0;
                    end
                end
            end

            COMPUTE_OUTGOING: begin
                // Initialize cost arrays
                if (day_counter == 8'd255 && city_counter == 8'd0) begin
                    integer i;
                    for (i = 0; i < 256; i = i + 1) begin
                        cost_from_metropolis[i] = 16'd0;
                    end
                end

                // Update cost for current day and city (backwards)
                if (city_counter < 8'd16) begin
                    // Find minimum cost flight from Metropolis (city 0)
                    temp_cost = 16'd0;
                    for (flight_index = 0; flight_index < flight_count; flight_index = flight_index + 1) begin
                        if (flight_mem_from[flight_index] == 5'd0 && 
                            flight_mem_day[flight_index] == day_counter &&
                            flight_mem_to[flight_index] == city_counter) begin
                            if (temp_cost == 16'd0 || flight_mem_cost[flight_index] < temp_cost) begin
                                temp_cost = flight_mem_cost[flight_index];
                            end
                        end
                    end

                    // If no flight found, keep next day's cost
                    if (temp_cost != 16'd0) begin
                        cost_from_metropolis[day_counter] = temp_cost;
                    end else if (day_counter < 8'd255) begin
                        cost_from_metropolis[day_counter] = cost_from_metropolis[day_counter + 1];
                    end

                    city_counter = city_counter + 8'd1;
                end else begin
                    city_counter = 8'd0;
                    day_counter = day_counter - 8'd1;

                    if (day_counter == 8'd0) begin
                        next_state = FIND_MIN;
                        day_counter = 8'd0;
                        current_min_cost = 16'd0;
                        found_solution = 1'b0;
                    end
                end
            end

            FIND_MIN: begin
                // Calculate total cost for each possible arrival day
                if (day_counter < 8'd256) begin
                    // Check if all cities can arrive by this day
                    arrival_day_cost = 16'd0;
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (cost_to_metropolis[day_counter] == 16'd0) begin
                            arrival_day_cost = 16'd0;
                            break;
                        end else begin
                            arrival_day_cost = arrival_day_cost + cost_to_metropolis[day_counter];
                        end
                    end

                    if (arrival_day_cost != 16'd0) begin
                        // Find earliest departure day (arrival_day + k_duration)
                        departure_day = day_counter + k_duration;
                        if (departure_day < 8'd256) begin
                            departure_day_cost = 16'd0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (cost_from_metropolis[departure_day] == 16'd0) begin
                                    departure_day_cost = 16'd0;
                                    break;
                                end else begin
                                    departure_day_cost = departure_day_cost + cost_from_metropolis[departure_day];
                                end
                            end

                            if (departure_day_cost != 16'd0) begin
                                total_cost = arrival_day_cost + departure_day_cost;
                                if (!found_solution || total_cost < current_min_cost) begin
                                    current_min_cost = total_cost;
                                    found_solution = 1'b1;
                                end
                            end
                        end
                    end

                    day_counter = day_counter + 8'd1;
                end else begin
                    if (found_solution) begin
                        min_cost = current_min_cost;
                        next_state = DONE_STATE;
                    end else begin
                        impossible = 1'b1;
                        next_state = DONE_STATE;
                    end
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
                impossible = 1'b0;
            end
        endcase
    end

endmodule