module AirlineFleetMinimization(
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

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] SORT       = 3'd2;
    localparam [2:0] BUILD_EDGES = 3'd3;
    localparam [2:0] MATCHING   = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Constants
    localparam [7:0] MAX_PLANES = 8'd4;
    localparam [7:0] MAX_CYCLES = 8'd700;

    // Counters
    reg [7:0] cycle_count;
    reg [4:0] load_counter;
    reg [4:0] sort_counter;
    reg [4:0] edge_counter;
    reg [9:0] matching_counter;

    // Data storage
    reg [31:0] inspection_times [0:3];
    reg [31:0] flight_times [0:15];
    reg [7:0] flights [0:11];

    // Sorted flights
    reg [7:0] sorted_flights [0:11];

    // Bipartite graph edges
    reg edges [0:15];

    // Matching variables
    reg [3:0] current_matching;
    reg [3:0] best_matching;
    reg [3:0] max_matching;

    // Temporary variables
    reg [31:0] temp_time;
    reg [7:0] temp_flight;
    reg [7:0] i, j, k;

    // Error flag
    reg load_error;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            load_counter <= 5'd0;
            sort_counter <= 5'd0;
            edge_counter <= 5'd0;
            matching_counter <= 10'd0;
            current_matching <= 4'd0;
            best_matching <= 4'd0;
            max_matching <= 4'd0;
            load_error <= 1'b0;

            // Initialize arrays
            for (i = 0; i < 4; i = i + 1) begin
                inspection_times[i] <= 32'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                flight_times[i] <= 32'd0;
            end
            for (i = 0; i < 12; i = i + 1) begin
                flights[i] <= 8'd0;
                sorted_flights[i] <= 8'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                edges[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (load_counter == 5'd31 && data_valid) begin
                    next_state = SORT;
                end else if (!data_valid && load_counter < 5'd31) begin
                    load_error = 1'b1;
                end
            end

            SORT: begin
                if (sort_counter == 5'd12) begin
                    next_state = BUILD_EDGES;
                end
            end

            BUILD_EDGES: begin
                if (edge_counter == 5'd16) begin
                    next_state = MATCHING;
                end
            end

            MATCHING: begin
                if (matching_counter == 10'd625) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 5'd0;
        end else if (state == LOAD && data_valid) begin
            case (data_type)
                2'd0: begin // Inspection times
                    if (load_counter < 5'd4) begin
                        inspection_times[load_counter] <= data_in;
                        load_counter <= load_counter + 5'd1;
                    end
                end
                2'd1: begin // Flight times
                    if (load_counter >= 5'd4 && load_counter < 5'd20) begin
                        flight_times[load_counter - 5'd4] <= data_in;
                        load_counter <= load_counter + 5'd1;
                    end
                end
                2'd2: begin // Flight data
                    if (load_counter >= 5'd20 && load_counter < 5'd32) begin
                        temp_flight <= data_in[7:0];
                        flights[load_counter - 5'd20] <= temp_flight;
                        load_counter <= load_counter + 5'd1;
                    end
                end
                default: load_error <= 1'b1;
            endcase
        end
    end

    // Bubble sort
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_counter <= 5'd0;
        end else if (state == SORT) begin
            if (sort_counter < 5'd12) begin
                i <= sort_counter[3:0];
                j <= sort_counter[4];
                if (j == 1'b0) begin
                    // Copy flights to sorted_flights
                    sorted_flights[i] <= flights[i];
                end else begin
                    // Compare and swap
                    if (sorted_flights[i] < sorted_flights[i+1]) begin
                        temp_flight <= sorted_flights[i];
                        sorted_flights[i] <= sorted_flights[i+1];
                        sorted_flights[i+1] <= temp_flight;
                    end
                end
                sort_counter <= sort_counter + 5'd1;
            end
        end
    end

    // Build edges
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_counter <= 5'd0;
        end else if (state == BUILD_EDGES) begin
            if (edge_counter < 5'd16) begin
                i <= edge_counter[3:0];
                j <= edge_counter[4];
                // Calculate edge based on flight times and inspection times
                // This is a simplified version - actual logic would be more complex
                edges[edge_counter] <= 1'b1;
                edge_counter <= edge_counter + 5'd1;
            end
        end
    end

    // Matching engine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            matching_counter <= 10'd0;
            current_matching <= 4'd0;
            best_matching <= 4'd0;
            max_matching <= 4'd0;
        end else if (state == MATCHING) begin
            if (matching_counter < 10'd625) begin
                // Brute-force matching logic
                // This is a simplified version - actual logic would evaluate all possibilities
                current_matching <= matching_counter[9:6];
                if (current_matching > best_matching) begin
                    best_matching <= current_matching;
                end
                matching_counter <= matching_counter + 10'd1;
            end else begin
                max_matching <= best_matching;
            end
        end
    end

    // Result calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= load_error;
                end
                DONE_STATE: begin
                    result <= MAX_PLANES - max_matching;
                    done <= 1'b1;
                    error <= load_error;
                end
                default: begin
                    done <= 1'b0;
                    error <= load_error;
                end
            endcase
        end
    end

    // Cycle counter for timeout
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE && state != DONE_STATE) begin
            if (cycle_count == MAX_CYCLES) begin
                next_state = IDLE;
                error <= 1'b1;
            end else begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

endmodule