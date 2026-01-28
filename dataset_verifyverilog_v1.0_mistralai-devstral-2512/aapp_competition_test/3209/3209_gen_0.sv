module TrainTimeCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [79:0] origin,
    input wire [79:0] dest,
    input wire [7:0] n,
    input wire [79:0] conn_origin [0:31],
    input wire [79:0] conn_dest [0:31],
    input wire [5:0] conn_min [0:31],
    input wire [8:0] conn_t [0:31],
    input wire [6:0] conn_p [0:31],
    input wire [6:0] conn_d [0:31],
    input wire valid_in,
    output reg [31:0] result,
    output reg valid_out,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Station mapping (16 stations max)
    reg [3:0] station_id [0:15];
    reg [3:0] origin_id, dest_id;
    reg [3:0] num_stations;

    // Edge storage (32 edges max)
    reg [3:0] edge_from [0:31];
    reg [3:0] edge_to [0:31];
    reg [5:0] edge_min [0:31];
    reg [8:0] edge_t [0:31];
    reg [6:0] edge_p [0:31];
    reg [6:0] edge_d [0:31];
    reg [4:0] num_edges;

    // Dijkstra algorithm variables
    reg signed [31:0] cost [0:15];
    reg [3:0] current_node;
    reg [7:0] iteration;

    // String comparison function
    function [1:0] string_compare;
        input [79:0] a, b;
        integer i;
        begin
            for (i = 0; i < 10; i = i + 1) begin
                if (a[8*i+7:8*i] != b[8*i+7:8*i]) begin
                    if (a[8*i+7:8*i] < b[8*i+7:8*i])
                        string_compare = 2'd1;
                    else
                        string_compare = 2'd2;
                end
            end
            string_compare = 2'd0; // equal
        end
    endfunction

    // String to ID mapping
    function [3:0] get_station_id;
        input [79:0] station;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                if (string_compare(station, conn_origin[i]) == 2'd0) begin
                    get_station_id = station_id[i];
                end
            end
            get_station_id = 4'd0; // default
        end
    endfunction

    // Fixed-point arithmetic
    function [31:0] fp_mult;
        input [31:0] a, b;
        reg [63:0] temp;
        begin
            temp = $signed(a) * $signed(b);
            fp_mult = temp[47:16]; // Q16.16 * Q16.16 = Q32.32, take middle 32 bits
        end
    endfunction

    function [31:0] fp_div;
        input [31:0] a, b;
        reg [63:0] temp;
        begin
            temp = {a, 16'd0}; // Shift left by 16
            fp_div = temp / b;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            valid_out <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 8'd0;
            num_stations <= 4'd0;
            num_edges <= 5'd0;
            origin_id <= 4'd0;
            dest_id <= 4'd0;
            
            // Initialize costs
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                cost[i] <= 32'd2147483647; // infinity in Q16.16
            end
            
            // Initialize station IDs
            for (i = 0; i < 16; i = i + 1) begin
                station_id[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start && valid_in) begin
                        next_state <= INPUT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INPUT: begin
                    // Map stations to IDs
                    integer i, j;
                    reg [3:0] new_id;
                    
                    // Reset station mapping
                    for (i = 0; i < 16; i = i + 1) begin
                        station_id[i] <= 4'd0;
                    end
                    
                    // Assign IDs to unique stations
                    new_id = 4'd0;
                    for (i = 0; i < 32; i = i + 1) begin
                        if (i < n) begin
                            // Check if origin already has ID
                            reg found;
                            found = 1'b0;
                            for (j = 0; j < 16; j = j + 1) begin
                                if (station_id[j] != 4'd0 && 
                                    string_compare(conn_origin[i], conn_origin[j]) == 2'd0) begin
                                    found = 1'b1;
                                end
                            end
                            
                            if (!found && new_id < 4'd16) begin
                                station_id[new_id] = new_id;
                                new_id = new_id + 4'd1;
                            end
                            
                            // Same for destination
                            found = 1'b0;
                            for (j = 0; j < 16; j = j + 1) begin
                                if (station_id[j] != 4'd0 && 
                                    string_compare(conn_dest[i], conn_dest[j]) == 2'd0) begin
                                    found = 1'b1;
                                end
                            end
                            
                            if (!found && new_id < 4'd16) begin
                                station_id[new_id] = new_id;
                                new_id = new_id + 4'd1;
                            end
                        end
                    end
                    
                    num_stations = new_id;
                    
                    // Map origin and destination
                    origin_id = get_station_id(origin);
                    dest_id = get_station_id(dest);
                    
                    // Store edges
                    for (i = 0; i < 32; i = i + 1) begin
                        if (i < n) begin
                            edge_from[i] = get_station_id(conn_origin[i]);
                            edge_to[i] = get_station_id(conn_dest[i]);
                            edge_min[i] = conn_min[i];
                            edge_t[i] = conn_t[i];
                            edge_p[i] = conn_p[i];
                            edge_d[i] = conn_d[i];
                        end else begin
                            edge_from[i] = 4'd0;
                            edge_to[i] = 4'd0;
                            edge_min[i] = 6'd0;
                            edge_t[i] = 9'd0;
                            edge_p[i] = 7'd0;
                            edge_d[i] = 7'd0;
                        end
                    end
                    num_edges = n;
                    
                    // Initialize costs
                    for (i = 0; i < 16; i = i + 1) begin
                        cost[i] <= 32'd2147483647;
                    end
                    cost[origin_id] <= 32'd0;
                    
                    next_state <= PROCESS;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count > MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Dijkstra iteration
                        integer i;
                        reg [3:0] min_node;
                        reg signed [31:0] min_cost;
                        
                        // Find node with minimum cost
                        min_cost = 32'd2147483647;
                        min_node = 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (cost[i] < min_cost) begin
                                min_cost = cost[i];
                                min_node = i;
                            end
                        end
                        
                        current_node = min_node;
                        
                        // Relax edges
                        for (i = 0; i < 32; i = i + 1) begin
                            if (edge_from[i] == current_node) begin
                                reg signed [31:0] new_cost;
                                reg signed [31:0] wait_time;
                                reg signed [31:0] expected_delay;
                                
                                // Calculate wait time (mod 60)
                                wait_time = (edge_min[i] - (min_cost[31:16] % 60)) + 32'd60;
                                wait_time = wait_time % 60;
                                
                                // Expected delay = (p * (d+1)) / 200
                                expected_delay = fp_mult(edge_p[i] << 16, (edge_d[i] + 7'd1) << 16);
                                expected_delay = fp_div(expected_delay, 200 << 16);
                                
                                // New cost = current + base_time + wait_time + expected_delay
                                new_cost = min_cost + (edge_t[i] << 16) + (wait_time << 16) + expected_delay;
                                
                                if (new_cost < cost[edge_to[i]]) begin
                                    cost[edge_to[i]] = new_cost;
                                end
                            end
                        end
                        
                        // Mark current node as visited
                        cost[current_node] = 32'd2147483647;
                        
                        // Check if we've processed all nodes
                        reg all_visited;
                        all_visited = 1'b1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (cost[i] != 32'd2147483647) begin
                                all_visited = 1'b0;
                            end
                        end
                        
                        if (all_visited || current_node == dest_id) begin
                            next_state <= OUTPUT;
                        end else begin
                            next_state <= PROCESS;
                        end
                    end
                end

                OUTPUT: begin
                    if (cost[dest_id] == 32'd2147483647) begin
                        impossible <= 1'b1;
                        result <= 32'd0;
                    end else begin
                        impossible <= 1'b0;
                        result <= cost[dest_id];
                    end
                    valid_out <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule