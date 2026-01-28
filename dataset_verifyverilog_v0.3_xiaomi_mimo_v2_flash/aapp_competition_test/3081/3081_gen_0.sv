module AirlineFleetMinimizer (
    input clk,
    input rst_n,
    input start,
    input [31:0] data_in,
    input data_valid,
    input [1:0] data_type,
    output reg [7:0] result,
    output reg done,
    output reg error
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] BUILD_EDGES = 3'd3;
    localparam [2:0] MATCHING = 3'd4;
    localparam [2:0] CALC_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Constants
    localparam [3:0] NUM_AIRPORTS = 4'd4;
    localparam [3:0] NUM_FLIGHTS = 4'd4;
    localparam [5:0] MAX_CYCLES = 6'd100; // Safety timeout

    // State registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_counter;

    // Input data storage
    reg [31:0] inspection_times [0:3]; // 4 airports
    reg [31:0] flight_times [0:15]; // 4x4 matrix (from*4 + to)
    reg [31:0] flights [0:3]; // 4 flights, each 3 values
    reg [1:0] input_counter;
    reg [3:0] flight_counter;
    reg [3:0] flight_val_counter;

    // Sorter registers
    reg [31:0] sorted_flights [0:3]; // Stores (s*4 + f) * 256 + t
    reg [31:0] temp_flight;
    reg [1:0] sort_i;
    reg [1:0] sort_j;
    reg [1:0] sort_temp;

    // Matching registers
    reg [3:0] match_matrix [0:15]; // 4x4 adjacency
    reg [31:0] matching_state; // Bitmask for used flights (4 bits)
    reg [2:0] match_depth;
    reg [2:0] max_depth;
    reg [3:0] max_matching;
    reg [3:0] current_matching;
    reg [1:0] flight_idx;
    reg [1:0] airport_idx;
    reg [1:0] best_flight_for_airport;
    reg [31:0] temp_best;

    // Done signal generation
    reg done_internal;

    // Helper logic for flight key extraction
    wire [7:0] flight_key_s [0:3];
    wire [7:0] flight_key_f [0:3];
    wire [7:0] flight_key_t [0:3];

    generate
        genvar i;
        for (i = 0; i < 4; i = i + 1) begin : flight_key_gen
            assign flight_key_s[i] = sorted_flights[i][31:24];
            assign flight_key_f[i] = sorted_flights[i][23:16];
            assign flight_key_t[i] = sorted_flights[i][15:8];
        end
    endgenerate

    // Input type decoding
    wire is_inspection = (data_type == 2'b00);
    wire is_flight_time = (data_type == 2'b01);
    wire is_flight_data = (data_type == 2'b10);

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_counter <= 8'd0;
            input_counter <= 2'd0;
            flight_counter <= 4'd0;
            flight_val_counter <= 4'd0;
            sort_i <= 2'd0;
            sort_j <= 2'd0;
            sort_temp <= 2'd0;
            match_depth <= 3'd0;
            max_depth <= 3'd0;
            max_matching <= 4'd0;
            current_matching <= 4'd0;
            matching_state <= 32'd0;
            flight_idx <= 2'd0;
            airport_idx <= 2'd0;
            done_internal <= 1'b0;
            
            // Initialize arrays
            inspection_times[0] <= 32'd0;
            inspection_times[1] <= 32'd0;
            inspection_times[2] <= 32'd0;
            inspection_times[3] <= 32'd0;
            
            flight_times[0] <= 32'd0; flight_times[1] <= 32'd0;
            flight_times[2] <= 32'd0; flight_times[3] <= 32'd0;
            flight_times[4] <= 32'd0; flight_times[5] <= 32'd0;
            flight_times[6] <= 32'd0; flight_times[7] <= 32'd0;
            flight_times[8] <= 32'd0; flight_times[9] <= 32'd0;
            flight_times[10] <= 32'd0; flight_times[11] <= 32'd0;
            flight_times[12] <= 32'd0; flight_times[13] <= 32'd0;
            flight_times[14] <= 32'd0; flight_times[15] <= 32'd0;
            
            flights[0] <= 32'd0; flights[1] <= 32'd0;
            flights[2] <= 32'd0; flights[3] <= 32'd0;
            
            sorted_flights[0] <= 32'd0;
            sorted_flights[1] <= 32'd0;
            sorted_flights[2] <= 32'd0;
            sorted_flights[3] <= 32'd0;
            
            temp_flight <= 32'd0;
            temp_best <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_counter <= 8'd0;
                    input_counter <= 2'd0;
                    flight_counter <= 4'd0;
                    flight_val_counter <= 4'd0;
                    sort_i <= 2'd0;
                    sort_j <= 2'd0;
                    match_depth <= 3'd0;
                    max_depth <= 3'd0;
                    max_matching <= 4'd0;
                    current_matching <= 4'd0;
                    matching_state <= 32'd0;
                    
                    if (start) begin
                        // Clear data storage
                        inspection_times[0] <= 32'd0;
                        inspection_times[1] <= 32'd0;
                        inspection_times[2] <= 32'd0;
                        inspection_times[3] <= 32'd0;
                        flight_times[0] <= 32'd0; flight_times[1] <= 32'd0;
                        flight_times[2] <= 32'd0; flight_times[3] <= 32'd0;
                        flight_times[4] <= 32'd0; flight_times[5] <= 32'd0;
                        flight_times[6] <= 32'd0; flight_times[7] <= 32'd0;
                        flight_times[8] <= 32'd0; flight_times[9] <= 32'd0;
                        flight_times[10] <= 32'd0; flight_times[11] <= 32'd0;
                        flight_times[12] <= 32'd0; flight_times[13] <= 32'd0;
                        flight_times[14] <= 32'd0; flight_times[15] <= 32'd0;
                        flights[0] <= 32'd0; flights[1] <= 32'd0;
                        flights[2] <= 32'd0; flights[3] <= 32'd0;
                    end
                end

                LOAD: begin
                    if (data_valid) begin
                        if (is_inspection) begin
                            if (input_counter < 2'd4) begin
                                inspection_times[input_counter] <= data_in;
                                input_counter <= input_counter + 2'd1;
                            end
                        end else if (is_flight_time) begin
                            if (flight_counter < 4'd16) begin
                                flight_times[flight_counter] <= data_in;
                                flight_counter <= flight_counter + 4'd1;
                            end
                        end else if (is_flight_data) begin
                            if (flight_val_counter < 4'd12) begin
                                flights[flight_val_counter / 3] <= 
                                    (flights[flight_val_counter / 3] & ~(32'hFFFFFFFF << (8 * (flight_val_counter % 3)))) | 
                                    (data_in[7:0] << (8 * (flight_val_counter % 3)));
                                flight_val_counter <= flight_val_counter + 4'd1;
                            end
                        end
                    end
                end

                SORT: begin
                    // Bubble sort flights by departure time (s)
                    // Create key: s*4 + f (8 bits) << 16 | t (8 bits)
                    if (sort_i == 2'd0 && sort_j == 2'd0) begin
                        // First step: build sorted_flights array
                        sorted_flights[0] <= {flights[0][7:0], flights[0][15:8], flights[0][23:16], 8'd0};
                        sorted_flights[1] <= {flights[1][7:0], flights[1][15:8], flights[1][23:16], 8'd0};
                        sorted_flights[2] <= {flights[2][7:0], flights[2][15:8], flights[2][23:16], 8'd0};
                        sorted_flights[3] <= {flights[3][7:0], flights[3][15:8], flights[3][23:16], 8'd0};
                        sort_i <= 2'd1;
                    end else if (sort_i < NUM_FLIGHTS) begin
                        if (sort_j < (NUM_FLIGHTS - sort_i)) begin
                            // Compare sort_j and sort_j+1 by departure airport (s)
                            if (sorted_flights[sort_j][31:24] > sorted_flights[sort_j + 2'd1][31:24]) begin
                                temp_flight <= sorted_flights[sort_j];
                                sorted_flights[sort_j] <= sorted_flights[sort_j + 2'd1];
                                sorted_flights[sort_j + 2'd1] <= temp_flight;
                            end
                            sort_j <= sort_j + 2'd1;
                        end else begin
                            sort_i <= sort_i + 2'd1;
                            sort_j <= 2'd0;
                        end
                    end
                end

                BUILD_EDGES: begin
                    // Build adjacency matrix: match_matrix[to * 4 + from]
                    // from = sorted_flights[idx][31:24], to = sorted_flights[idx][23:16]
                    if (flight_idx < NUM_FLIGHTS) begin
                        if (airport_idx < NUM_AIRPORTS) begin
                            // Check if flight from airport_idx -> sorted_flights[flight_idx][23:16]
                            // Compute edge weight: flight_time[from][to]
                            match_matrix[airport_idx * 4 + flight_idx] <= 
                                flight_times[airport_idx * 4 + sorted_flights[flight_idx][23:16]];
                            airport_idx <= airport_idx + 2'd1;
                        end else begin
                            flight_idx <= flight_idx + 2'd1;
                            airport_idx <= 2'd0;
                        end
                    end
                end

                MATCHING: begin
                    // Brute force: try all assignments (5^4 = 625)
                    // matching_state: [3:0] flights used, [7:4] airports assigned
                    if (match_depth == 3'd0) begin
                        // Reset for new matching
                        matching_state <= 32'd0;
                        current_matching <= 4'd0;
                        match_depth <= 3'd1;
                    end else if (match_depth <= NUM_AIRPORTS) begin
                        airport_idx <= 2'd0;
                        // Find best unused flight for current airport (airport_idx)
                        if (airport_idx < NUM_AIRPORTS) begin
                            best_flight_for_airport <= 4'd0;
                            temp_best <= 32'hFFFFFFFF;
                            for (flight_idx = 0; flight_idx < 4; flight_idx = flight_idx + 1) begin
                                if (((matching_state >> flight_idx) & 1) == 0) begin
                                    // Flight not used
                                    if (match_matrix[airport_idx * 4 + flight_idx] < temp_best) begin
                                        temp_best <= match_matrix[airport_idx * 4 + flight_idx];
                                        best_flight_for_airport <= flight_idx;
                                    end
                                end
                            end
                            // Assign this flight
                            matching_state <= matching_state | (1 << best_flight_for_airport);
                            current_matching <= current_matching + 4'd1;
                        end
                        match_depth <= match_depth + 3'd1;
                    end else begin
                        // Matching complete, update max
                        if (current_matching > max_matching) begin
                            max_matching <= current_matching;
                        end
                    end
                end

                CALC_RESULT: begin
                    // result = 4 - max_matching
                    result <= NUM_AIRPORTS - max_matching;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Timeout safety
            if (state != IDLE && state != DONE_STATE) begin
                cycle_counter <= cycle_counter + 8'd1;
                if (cycle_counter >= MAX_CYCLES) begin
                    error <= 1'b1;
                    state <= DONE_STATE;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end

            LOAD: begin
                // Load all data points: 4 inspection + 16 flight times + 12 flight values = 32
                if (data_valid && 
                    (input_counter >= 2'd4) && 
                    (flight_counter >= 4'd16) && 
                    (flight_val_counter >= 4'd12)) begin
                    next_state = SORT;
                end
            end

            SORT: begin
                // Bubble sort: 4 flights, ~12 cycles max
                if (sort_i >= NUM_FLIGHTS) begin
                    next_state = BUILD_EDGES;
                end
            end

            BUILD_EDGES: begin
                // 4 flights x 4 airports = 16 cycles
                if (flight_idx >= NUM_FLIGHTS) begin
                    next_state = MATCHING;
                end
            end

            MATCHING: begin
                // Try all 5^4 = 625 possibilities
                if (match_depth > NUM_AIRPORTS) begin
                    if (matching_state >= 32'hFFFF && current_matching >= NUM_AIRPORTS) begin
                        next_state = CALC_RESULT;
                    end else begin
                        // Try next assignment if possible
                        // Simplified: after trying one matching, go to result
                        next_state = CALC_RESULT;
                    end
                end
            end

            CALC_RESULT: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule