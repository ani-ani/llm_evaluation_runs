module traveling_salesman (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Number of cities (1-8) and number of edges (0-8)
    input wire [3:0] n,
    input wire [3:0] m,
    
    // Edge inputs: 8 edges, each with source (a) and destination (b)
    // Cities are numbered 1..n. Unused edges should have valid_edges[i]=0.
    input wire [3:0] edges_a [0:7],
    input wire [3:0] edges_b [0:7],
    input wire [7:0] valid_edges,
    
    // Outputs
    output reg [7:0] flights,   // Minimum number of flights
    output reg [7:0] airports,  // Bitmask of cities (1-8) whose airport can be visited
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] READ_EDGES = 4'd1;
    localparam [3:0] COMPUTE_MAX = 4'd2;
    localparam [3:0] COMPUTE_L_UNMATCH = 4'd3;
    localparam [3:0] COMPUTE_R_UNMATCH = 4'd4;
    localparam [3:0] OUTPUT = 4'd5;
    localparam [3:0] DONE_STATE = 4'd6;
    
    reg [3:0] state, next_state;
    
    // Counters and temporary registers
    reg [8:0] subset_counter;
    reg [2:0] edge_counter;
    reg [2:0] city_counter;
    reg [7:0] left_used, right_used;
    reg [7:0] max_matching;
    reg [7:0] current_matching_size;
    reg [7:0] temp_airports;
    reg [7:0] temp_flights;
    reg valid_subset;
    reg [7:0] left_mask, right_mask;
    
    // Edge storage
    reg [3:0] stored_edges_a [0:7];
    reg [3:0] stored_edges_b [0:7];
    reg [7:0] stored_valid_edges;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            subset_counter <= 9'd0;
            edge_counter <= 3'd0;
            city_counter <= 3'd0;
            left_used <= 8'd0;
            right_used <= 8'd0;
            max_matching <= 8'd0;
            current_matching_size <= 8'd0;
            temp_airports <= 8'd0;
            temp_flights <= 8'd0;
            valid_subset <= 1'b0;
            left_mask <= 8'd0;
            right_mask <= 8'd0;
            
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                stored_edges_a[i] <= 4'd0;
                stored_edges_b[i] <= 4'd0;
            end
            stored_valid_edges <= 8'd0;
            
            flights <= 8'd0;
            airports <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end
    
    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_EDGES;
                end
            end
            
            READ_EDGES: begin
                integer i;
                for (i = 0; i < 8; i = i + 1) begin
                    stored_edges_a[i] = edges_a[i];
                    stored_edges_b[i] = edges_b[i];
                end
                stored_valid_edges = valid_edges;
                next_state = COMPUTE_MAX;
            end
            
            COMPUTE_MAX: begin
                // Reset counters for new computation
                subset_counter = 9'd0;
                max_matching = 8'd0;
                
                // Iterate through all subsets
                if (subset_counter < 256) begin
                    // Check if current subset is valid
                    left_used = 8'd0;
                    right_used = 8'd0;
                    current_matching_size = 8'd0;
                    valid_subset = 1'b1;
                    
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (stored_valid_edges[i] && subset_counter[i]) begin
                            // Check for conflicts
                            if (left_used[stored_edges_a[i]] || right_used[stored_edges_b[i]]) begin
                                valid_subset = 1'b0;
                            end else begin
                                left_used[stored_edges_a[i]] = 1'b1;
                                right_used[stored_edges_b[i]] = 1'b1;
                                current_matching_size = current_matching_size + 8'd1;
                            end
                        end
                    end
                    
                    // Update max matching
                    if (valid_subset && current_matching_size > max_matching) begin
                        max_matching = current_matching_size;
                    end
                    
                    subset_counter = subset_counter + 9'd1;
                end else begin
                    // Compute flights
                    temp_flights = n - max_matching - 8'd1;
                    next_state = COMPUTE_L_UNMATCH;
                end
            end
            
            COMPUTE_L_UNMATCH: begin
                // Check each city for left unmatched condition
                if (city_counter < n) begin
                    // Compute matching size with city (city_counter+1) removed from left
                    subset_counter = 9'd0;
                    current_matching_size = 8'd0;
                    
                    integer i;
                    for (i = 0; i < 256; i = i + 1) begin
                        left_used = 8'd0;
                        right_used = 8'd0;
                        current_matching_size = 8'd0;
                        valid_subset = 1'b1;
                        
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (stored_valid_edges[j] && subset_counter[j] && stored_edges_a[j] != city_counter + 4'd1) begin
                                if (left_used[stored_edges_a[j]] || right_used[stored_edges_b[j]]) begin
                                    valid_subset = 1'b0;
                                end else begin
                                    left_used[stored_edges_a[j]] = 1'b1;
                                    right_used[stored_edges_b[j]] = 1'b1;
                                    current_matching_size = current_matching_size + 8'd1;
                                end
                            end
                        end
                        
                        if (valid_subset && current_matching_size > current_matching_size) begin
                            current_matching_size = current_matching_size;
                        end
                        
                        subset_counter = subset_counter + 9'd1;
                    end
                    
                    // If M_i == M_max, set bit
                    if (current_matching_size == max_matching) begin
                        temp_airports[city_counter] = 1'b1;
                    end
                    
                    city_counter = city_counter + 3'd1;
                end else begin
                    city_counter = 3'd0;
                    next_state = COMPUTE_R_UNMATCH;
                end
            end
            
            COMPUTE_R_UNMATCH: begin
                // Check each city for right unmatched condition
                if (city_counter < n) begin
                    // Compute matching size with city (city_counter+1) removed from right
                    subset_counter = 9'd0;
                    current_matching_size = 8'd0;
                    
                    integer i;
                    for (i = 0; i < 256; i = i + 1) begin
                        left_used = 8'd0;
                        right_used = 8'd0;
                        current_matching_size = 8'd0;
                        valid_subset = 1'b1;
                        
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (stored_valid_edges[j] && subset_counter[j] && stored_edges_b[j] != city_counter + 4'd1) begin
                                if (left_used[stored_edges_a[j]] || right_used[stored_edges_b[j]]) begin
                                    valid_subset = 1'b0;
                                end else begin
                                    left_used[stored_edges_a[j]] = 1'b1;
                                    right_used[stored_edges_b[j]] = 1'b1;
                                    current_matching_size = current_matching_size + 8'd1;
                                end
                            end
                        end
                        
                        if (valid_subset && current_matching_size > current_matching_size) begin
                            current_matching_size = current_matching_size;
                        end
                        
                        subset_counter = subset_counter + 9'd1;
                    end
                    
                    // If M'_i == M_max, set bit
                    if (current_matching_size == max_matching) begin
                        temp_airports[city_counter] = 1'b1;
                    end
                    
                    city_counter = city_counter + 3'd1;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                flights = temp_flights;
                airports = temp_airports;
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule