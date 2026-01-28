module traveling_salesman (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [3:0] edges_a [0:7],
    input wire [3:0] edges_b [0:7],
    input wire [7:0] valid_edges,
    output reg [7:0] flights,
    output reg [7:0] airports,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] READ_EDGES = 4'd1;
    localparam [3:0] COMPUTE_MAX = 4'd2;
    localparam [3:0] COMPUTE_L_UNMATCH = 4'd3;
    localparam [3:0] COMPUTE_R_UNMATCH = 4'd4;
    localparam [3:0] OUTPUT = 4'd5;
    localparam [3:0] DONE = 4'd6;
    localparam [3:0] RESET_LOOP = 4'd7;
    localparam [3:0] CHECK_SUBSET = 4'd8;
    localparam [3:0] UPDATE_MAX = 4'd9;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] reg_edges_a [0:7];
    reg [7:0] reg_edges_b [0:7];
    reg [7:0] reg_valid_edges;
    reg [7:0] reg_n;
    reg [7:0] reg_m;
    
    // Loop counters
    reg [7:0] subset_counter;
    reg [3:0] edge_idx;
    reg [3:0] city_idx;
    reg [3:0] target_city;
    
    // Matching computation state
    reg [7:0] used_left;
    reg [7:0] used_right;
    reg [7:0] current_size;
    reg [7:0] best_size;
    reg [7:0] current_subset;
    reg conflict_detected;
    reg [3:0] current_edge_a;
    reg [3:0] current_edge_b;
    reg [7:0] max_matching_original;
    reg [7:0] max_matching_l_removed;
    reg [7:0] max_matching_r_removed;
    
    // Control signals
    reg start_computation;
    reg computation_done;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            flights <= 8'd0;
            airports <= 8'd0;
            done <= 1'b0;
            subset_counter <= 8'd0;
            edge_idx <= 4'd0;
            city_idx <= 4'd1;
            target_city <= 4'd0;
            used_left <= 8'd0;
            used_right <= 8'd0;
            current_size <= 8'd0;
            best_size <= 8'd0;
            current_subset <= 8'd0;
            conflict_detected <= 1'b0;
            current_edge_a <= 4'd0;
            current_edge_b <= 4'd0;
            max_matching_original <= 8'd0;
            max_matching_l_removed <= 8'd0;
            max_matching_r_removed <= 8'd0;
            reg_n <= 8'd0;
            reg_m <= 8'd0;
            reg_valid_edges <= 8'd0;
            reg_edges_a[0] <= 8'd0; reg_edges_a[1] <= 8'd0; reg_edges_a[2] <= 8'd0; reg_edges_a[3] <= 8'd0;
            reg_edges_a[4] <= 8'd0; reg_edges_a[5] <= 8'd0; reg_edges_a[6] <= 8'd0; reg_edges_a[7] <= 8'd0;
            reg_edges_b[0] <= 8'd0; reg_edges_b[1] <= 8'd0; reg_edges_b[2] <= 8'd0; reg_edges_b[3] <= 8'd0;
            reg_edges_b[4] <= 8'd0; reg_edges_b[5] <= 8'd0; reg_edges_b[6] <= 8'd0; reg_edges_b[7] <= 8'd0;
            cycle_counter <= 8'd0;
            start_computation <= 1'b0;
            computation_done <= 1'b0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        reg_n <= n;
                        reg_m <= m;
                        start_computation <= 1'b1;
                    end else begin
                        start_computation <= 1'b0;
                    end
                end
                
                READ_EDGES: begin
                    reg_valid_edges <= valid_edges;
                    // Store edges with 1-based indexing for clarity
                    reg_edges_a[0] <= edges_a[0] + 8'd1;
                    reg_edges_a[1] <= edges_a[1] + 8'd1;
                    reg_edges_a[2] <= edges_a[2] + 8'd1;
                    reg_edges_a[3] <= edges_a[3] + 8'd1;
                    reg_edges_a[4] <= edges_a[4] + 8'd1;
                    reg_edges_a[5] <= edges_a[5] + 8'd1;
                    reg_edges_a[6] <= edges_a[6] + 8'd1;
                    reg_edges_a[7] <= edges_a[7] + 8'd1;
                    reg_edges_b[0] <= edges_b[0] + 8'd1;
                    reg_edges_b[1] <= edges_b[1] + 8'd1;
                    reg_edges_b[2] <= edges_b[2] + 8'd1;
                    reg_edges_b[3] <= edges_b[3] + 8'd1;
                    reg_edges_b[4] <= edges_b[4] + 8'd1;
                    reg_edges_b[5] <= edges_b[5] + 8'd1;
                    reg_edges_b[6] <= edges_b[6] + 8'd1;
                    reg_edges_b[7] <= edges_b[7] + 8'd1;
                    subset_counter <= 8'd0;
                    best_size <= 8'd0;
                end
                
                RESET_LOOP: begin
                    used_left <= 8'd0;
                    used_right <= 8'd0;
                    current_size <= 8'd0;
                    conflict_detected <= 1'b0;
                    edge_idx <= 4'd0;
                end
                
                CHECK_SUBSET: begin
                    if (reg_valid_edges[edge_idx]) begin
                        current_edge_a <= reg_edges_a[edge_idx];
                        current_edge_b <= reg_edges_b[edge_idx];
                    end else begin
                        current_edge_a <= 8'd0;
                        current_edge_b <= 8'd0;
                    end
                end
                
                UPDATE_MAX: begin
                    // Check if current_edge is in subset
                    if (reg_valid_edges[edge_idx] && (current_subset & (8'd1 << edge_idx))) begin
                        // Check if cities are valid for current computation
                        if (target_city == 4'd0 || 
                           (current_edge_a != target_city && current_edge_b != target_city)) begin
                            // Check for conflict
                            if (used_left[current_edge_a - 1] || used_right[current_edge_b - 1]) begin
                                conflict_detected <= 1'b1;
                            end else begin
                                used_left[current_edge_a - 1] <= 1'b1;
                                used_right[current_edge_b - 1] <= 1'b1;
                                current_size <= current_size + 8'd1;
                            end
                        end
                    end
                end
                
                COMPUTE_MAX: begin
                    // Find max matching size
                    if (!conflict_detected && current_size > best_size) begin
                        best_size <= current_size;
                    end
                    
                    // Increment subset_counter
                    if (cycle_counter < 8'd100) begin
                        cycle_counter <= cycle_counter + 8'd1;
                    end
                end
                
                COMPUTE_L_UNMATCH: begin
                    if (current_size > max_matching_l_removed) begin
                        max_matching_l_removed <= current_size;
                    end
                end
                
                COMPUTE_R_UNMATCH: begin
                    if (current_size > max_matching_r_removed) begin
                        max_matching_r_removed <= current_size;
                    end
                end
                
                OUTPUT: begin
                    // Compute flights
                    flights <= reg_n - best_size - 8'd1;
                    
                    // Compute airports bitmask
                    if (city_idx <= reg_n) begin
                        if (city_idx == 1) begin
                            airports <= 8'd0;
                        end
                        // Check if city can be start (not required on left)
                        if (max_matching_l_removed == best_size || max_matching_r_removed == best_size) begin
                            airports[city_idx - 1] <= 1'b1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    start_computation <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_computation) next_state = READ_EDGES;
            end
            
            READ_EDGES: begin
                next_state = RESET_LOOP;
            end
            
            RESET_LOOP: begin
                next_state = CHECK_SUBSET;
            end
            
            CHECK_SUBSET: begin
                if (edge_idx < 4'd8) next_state = UPDATE_MAX;
                else next_state = COMPUTE_MAX;
            end
            
            UPDATE_MAX: begin
                if (edge_idx < 4'd7) next_state = CHECK_SUBSET;
                else next_state = COMPUTE_MAX;
            end
            
            COMPUTE_MAX: begin
                if (subset_counter < 8'd255 && cycle_counter < 8'd100) begin
                    next_state = RESET_LOOP;
                end else begin
                    next_state = COMPUTE_L_UNMATCH;
                end
            end
            
            COMPUTE_L_UNMATCH: begin
                // Reset for next city
                if (city_idx <= reg_n) next_state = RESET_LOOP;
                else next_state = COMPUTE_R_UNMATCH;
            end
            
            COMPUTE_R_UNMATCH: begin
                // Reset for next city
                if (city_idx <= reg_n) next_state = RESET_LOOP;
                else next_state = OUTPUT;
            end
            
            OUTPUT: begin
                if (city_idx > reg_n) next_state = DONE;
                else next_state = OUTPUT;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule