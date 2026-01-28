module truck_encounter_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_en,
    input wire [3:0] addr_in,
    input wire [7:0] data_in,
    output reg result_valid,
    output reg [7:0] result_count,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CONFIG    = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Configuration storage
    reg [7:0] route_length [0:15];
    reg [7:0] route_cities [0:15][0:7];
    reg [7:0] query_pairs [0:15];

    // Processing variables
    reg [3:0] current_query;
    reg [3:0] truck_a, truck_b;
    reg [7:0] encounter_count;

    // Segment processing
    reg [3:0] seg_a_idx, seg_b_idx;
    reg [7:0] seg_a_start_time, seg_a_end_time;
    reg [7:0] seg_a_start_pos, seg_a_end_pos;
    reg [7:0] seg_b_start_time, seg_b_end_time;
    reg [7:0] seg_b_start_pos, seg_b_end_pos;

    // Intersection calculation
    reg signed [15:0] numerator, denominator;
    reg [7:0] intersection_time;
    reg intersection_valid;

    // Configuration counters
    reg [3:0] config_truck_idx;
    reg [2:0] config_city_idx;
    reg [3:0] config_query_idx;
    reg config_phase; // 0=length, 1=cities

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_valid <= 1'b0;
            result_count <= 8'd0;
            busy <= 1'b0;
            current_query <= 4'd0;
            encounter_count <= 8'd0;
            seg_a_idx <= 4'd0;
            seg_b_idx <= 4'd0;
            config_truck_idx <= 4'd0;
            config_city_idx <= 3'd0;
            config_query_idx <= 4'd0;
            config_phase <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize route storage
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                route_length[i] <= 8'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    route_cities[i][j] <= 8'd0;
                end
            end

            // Initialize query storage
            for (i = 0; i < 16; i = i + 1) begin
                query_pairs[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    result_valid <= 1'b0;
                    if (start) begin
                        next_state <= CONFIG;
                        busy <= 1'b1;
                        config_truck_idx <= 4'd0;
                        config_city_idx <= 3'd0;
                        config_query_idx <= 4'd0;
                        config_phase <= 1'b0;
                    end
                end

                CONFIG: begin
                    if (config_en == 1'b0) begin
                        // Route configuration
                        if (config_phase == 1'b0) begin
                            // Store length
                            route_length[config_truck_idx] <= data_in;
                            config_phase <= 1'b1;
                            config_city_idx <= 3'd0;
                        end else begin
                            // Store city
                            route_cities[config_truck_idx][config_city_idx] <= data_in;
                            config_city_idx <= config_city_idx + 1'b1;
                            
                            // Check if done with this truck
                            if (config_city_idx == route_length[config_truck_idx]) begin
                                config_phase <= 1'b0;
                                config_truck_idx <= config_truck_idx + 1'b1;
                                
                                // Check if all trucks configured
                                if (config_truck_idx == 4'd16) begin
                                    next_state <= PROCESS;
                                    current_query <= 4'd0;
                                end
                            end
                        end
                    end else begin
                        // Query configuration
                        query_pairs[config_query_idx] <= data_in;
                        config_query_idx <= config_query_idx + 1'b1;
                        
                        // Check if all queries configured
                        if (config_query_idx == 4'd16) begin
                            next_state <= PROCESS;
                            current_query <= 4'd0;
                        end
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current query
                    truck_a <= query_pairs[current_query][7:4];
                    truck_b <= query_pairs[current_query][3:0];
                    
                    // Initialize segment counters
                    if (cycle_count == 8'd1) begin
                        seg_a_idx <= 4'd0;
                        seg_b_idx <= 4'd0;
                        encounter_count <= 8'd0;
                    end
                    
                    // Get current segments
                    if (seg_a_idx < route_length[truck_a] - 1'b1) begin
                        seg_a_start_pos <= route_cities[truck_a][seg_a_idx];
                        seg_a_end_pos <= route_cities[truck_a][seg_a_idx + 1'b1];
                        seg_a_start_time <= (seg_a_idx == 4'd0) ? 8'd0 : 
                                            seg_a_start_time + (seg_a_end_pos > seg_a_start_pos) ? 
                                            (seg_a_end_pos - seg_a_start_pos) : 
                                            (seg_a_start_pos - seg_a_end_pos);
                        seg_a_end_time <= seg_a_start_time + (seg_a_end_pos > seg_a_start_pos) ? 
                                        (seg_a_end_pos - seg_a_start_pos) : 
                                        (seg_a_start_pos - seg_a_end_pos);
                    end
                    
                    if (seg_b_idx < route_length[truck_b] - 1'b1) begin
                        seg_b_start_pos <= route_cities[truck_b][seg_b_idx];
                        seg_b_end_pos <= route_cities[truck_b][seg_b_idx + 1'b1];
                        seg_b_start_time <= (seg_b_idx == 4'd0) ? 8'd0 : 
                                            seg_b_start_time + (seg_b_end_pos > seg_b_start_pos) ? 
                                            (seg_b_end_pos - seg_b_start_pos) : 
                                            (seg_b_start_pos - seg_b_end_pos);
                        seg_b_end_time <= seg_b_start_time + (seg_b_end_pos > seg_b_start_pos) ? 
                                        (seg_b_end_pos - seg_b_start_pos) : 
                                        (seg_b_start_pos - seg_b_end_pos);
                    end
                    
                    // Check for intersection
                    if (seg_a_idx < route_length[truck_a] - 1'b1 && 
                        seg_b_idx < route_length[truck_b] - 1'b1) begin
                        
                        // Calculate denominator (cross product)
                        denominator <= (seg_a_end_pos - seg_a_start_pos) * (seg_b_end_time - seg_b_start_time) -
                                      (seg_b_end_pos - seg_b_start_pos) * (seg_a_end_time - seg_a_start_time);
                        
                        // Check if segments are not parallel
                        if (denominator != 16'd0) begin
                            // Calculate numerator for time
                            numerator <= (seg_b_end_pos - seg_b_start_pos) * (seg_a_start_time - seg_b_start_time) -
                                         (seg_a_start_pos - seg_b_start_pos) * (seg_b_end_time - seg_b_start_time);
                            
                            // Calculate intersection time (Q8.8 format)
                            intersection_time <= (numerator / denominator) + seg_b_start_time;
                            
                            // Check if intersection is within both segments (excluding endpoints)
                            intersection_valid <= (intersection_time > seg_a_start_time) &&
                                                (intersection_time < seg_a_end_time) &&
                                                (intersection_time > seg_b_start_time) &&
                                                (intersection_time < seg_b_end_time);
                            
                            if (intersection_valid) begin
                                encounter_count <= encounter_count + 8'd1;
                            end
                        end
                        
                        // Move to next segment pair
                        seg_b_idx <= seg_b_idx + 1'b1;
                        if (seg_b_idx == route_length[truck_b] - 1'b1) begin
                            seg_b_idx <= 4'd0;
                            seg_a_idx <= seg_a_idx + 1'b1;
                            
                            if (seg_a_idx == route_length[truck_a] - 1'b1) begin
                                // Done with this query
                                result_count <= encounter_count;
                                next_state <= OUTPUT;
                                cycle_count <= 8'd0;
                            end
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                        result_count <= encounter_count;
                        cycle_count <= 8'd0;
                    end
                end

                OUTPUT: begin
                    result_valid <= 1'b1;
                    next_state <= IDLE;
                    
                    // Move to next query
                    current_query <= current_query + 1'b1;
                    
                    // Check if all queries processed
                    if (current_query == 4'd16) begin
                        busy <= 1'b0;
                    end else begin
                        next_state <= PROCESS;
                    end
                end

                DONE_STATE: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule