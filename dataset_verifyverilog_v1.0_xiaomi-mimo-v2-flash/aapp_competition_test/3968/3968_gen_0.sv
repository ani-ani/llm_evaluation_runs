module virus_spread_simulation(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [5:0] D,
    input wire [3:0] initial_infected_count,
    input wire [15:0] initial_infected_idx,
    input wire [31:0] s_arr [15:0],
    input wire [31:0] t_arr [15:0],
    output reg [15:0] result_mask,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_DATA = 3'd1;
    localparam [2:0] COMPUTE_GRAPH = 3'd2;
    localparam [2:0] SIMULATE  = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Registers for state and data
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] infected_mask;
    reg [15:0] new_infected_mask;
    reg [15:0] contact_matrix [15:0]; // 16x16 bit matrix
    reg [31:0] s_reg [15:0];
    reg [31:0] t_reg [15:0];
    
    // Counters
    reg [3:0] node_i; // Outer loop index
    reg [3:0] node_j; // Inner loop index
    reg [5:0] day_counter;
    reg [5:0] cycle_count; // Prevention for infinite loops
    localparam [5:0] MAX_CYCLES = 6'd63;
    
    // Temporary registers for computation
    reg [31:0] s_i_val;
    reg [31:0] t_i_val;
    reg [31:0] s_j_val;
    reg [31:0] t_j_val;
    reg overlap_result;
    
    // Combinational overlap logic
    wire overlap_condition;
    // Overlap: !(t_i < s_j || t_j < s_i)
    // Since Q16.16 is unsigned fixed point, direct comparison works
    assign overlap_condition = !( (t_i_val < s_j_val) || (t_j_val < s_i_val) );

    // Main state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_mask <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            infected_mask <= 16'd0;
            new_infected_mask <= 16'd0;
            node_i <= 4'd0;
            node_j <= 4'd0;
            day_counter <= 6'd0;
            cycle_count <= 6'd0;
            s_i_val <= 32'd0;
            t_i_val <= 32'd0;
            s_j_val <= 32'd0;
            t_j_val <= 32'd0;
            overlap_result <= 1'b0;
            // Initialize contact matrix
            for (int k = 0; k < 16; k = k + 1) begin
                contact_matrix[k] <= 16'd0;
            end
            // Initialize s/t registers
            for (int k = 0; k < 16; k = k + 1) begin
                s_reg[k] <= 32'd0;
                t_reg[k] <= 32'd0;
            end
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    node_i <= 4'd0;
                    node_j <= 4'd0;
                    day_counter <= 6'd0;
                    cycle_count <= 6'd0;
                    infected_mask <= 16'd0;
                    new_infected_mask <= 16'd0;
                    result_mask <= 16'd0;
                    // Clear contact matrix
                    for (int k = 0; k < 16; k = k + 1) begin
                        contact_matrix[k] <= 16'd0;
                    end
                    // Clear s/t registers
                    for (int k = 0; k < 16; k = k + 1) begin
                        s_reg[k] <= 32'd0;
                        t_reg[k] <= 32'd0;
                    end
                    
                    if (start) begin
                        state <= LOAD_DATA;
                        busy <= 1'b1;
                    end
                end

                LOAD_DATA: begin
                    // Store input arrays into internal registers
                    // Load 16 entries (N <= 16, but we load all 16 for simplicity)
                    if (node_i < 4'd16) begin
                        s_reg[node_i] <= s_arr[node_i];
                        t_reg[node_i] <= t_arr[node_i];
                        node_i <= node_i + 4'd1;
                    end else begin
                        node_i <= 4'd0;
                        node_j <= 4'd0;
                        state <= COMPUTE_GRAPH;
                    end
                end

                COMPUTE_GRAPH: begin
                    // Compute contact matrix M[i][j]
                    // Loop over i (0 to N-1), j (0 to N-1)
                    // Reset temporaries for first iteration
                    if (node_i == 4'd0 && node_j == 4'd0) begin
                        s_i_val <= s_reg[0];
                        t_i_val <= t_reg[0];
                        s_j_val <= s_reg[0];
                        t_j_val <= t_reg[0];
                    end
                    
                    // Check if indices are within valid N
                    if (node_i < N && node_j < N) begin
                        // Calculate overlap
                        // !(t_i < s_j || t_j < s_i)
                        if ( (t_i_val < s_j_val) || (t_j_val < s_i_val) ) begin
                            overlap_result <= 1'b0;
                        end else begin
                            overlap_result <= 1'b1;
                        end
                        
                        // Update next state logic (delayed by 1 cycle for computation)
                        // Actually, we need to handle the matrix update in next cycle
                        // So we'll modify control flow
                        
                        // Advance j
                        if (node_j < N - 4'd1) begin
                            node_j <= node_j + 4'd1;
                            // Update temporaries for next j
                            s_j_val <= s_reg[node_j + 4'd1];
                            t_j_val <= t_reg[node_j + 4'd1];
                        end else begin
                            // Done with this row i
                            node_j <= 4'd0;
                            // Update temporaries for next i (starting j=0)
                            s_j_val <= s_reg[0];
                            t_j_val <= t_reg[0];
                            
                            if (node_i < N - 4'd1) begin
                                node_i <= node_i + 4'd1;
                                // Update temporaries for next i
                                s_i_val <= s_reg[node_i + 4'd1];
                                t_i_val <= t_reg[node_i + 4'd1];
                            end else begin
                                // All done, go to simulate
                                node_i <= 4'd0;
                                state <= SIMULATE;
                            end
                        end
                    end else begin
                        // Skip if outside N
                        if (node_j < N - 4'd1) begin
                            node_j <= node_j + 4'd1;
                        end else begin
                            node_j <= 4'd0;
                            if (node_i < N - 4'd1) begin
                                node_i <= node_i + 4'd1;
                            end else begin
                                node_i <= 4'd0;
                                state <= SIMULATE;
                            end
                        end
                    end
                    
                    // Update matrix with result from previous cycle
                    // (overlap_result is valid now)
                    if (node_i < N && node_j < N) begin
                        if (overlap_result) begin
                            contact_matrix[node_i][node_j] <= 1'b1;
                        end else begin
                            contact_matrix[node_i][node_j] <= 1'b0;
                        end
                    end
                end

                SIMULATE: begin
                    // Initialize infected mask on first day
                    if (day_counter == 6'd0) begin
                        infected_mask <= initial_infected_idx;
                        day_counter <= 6'd1;
                        node_i <= 4'd0; // Use i for infected nodes
                        node_j <= 4'd0; // Use j for target nodes
                        new_infected_mask <= 16'd0;
                    end else if (day_counter <= D) begin
                        // BFS-like propagation
                        // For each infected node i
                        // For each uninfected node j
                        // If M[i][j] == 1, set j in new_infected
                        
                        // Check if current node_i is infected
                        if (node_i < N) begin
                            if (infected_mask[node_i]) begin
                                // This node is infected, check contacts
                                if (node_j < N) begin
                                    // Check if target node j is NOT already infected
                                    if (!infected_mask[node_j]) begin
                                        // Check contact
                                        if (contact_matrix[node_i][node_j]) begin
                                            new_infected_mask[node_j] <= 1'b1;
                                        end
                                    end
                                    node_j <= node_j + 4'd1;
                                end else begin
                                    // Done with j for this i
                                    node_j <= 4'd0;
                                    node_i <= node_i + 4'd1;
                                end
                            end else begin
                                // Node i not infected, skip to next i
                                node_i <= node_i + 4'd1;
                            end
                        end else begin
                            // Finished all i for this day
                            // Update infected mask
                            infected_mask <= infected_mask | new_infected_mask;
                            // Prepare for next day
                            day_counter <= day_counter + 6'd1;
                            node_i <= 4'd0;
                            node_j <= 4'd0;
                            new_infected_mask <= 16'd0;
                            
                            // Check if done all days
                            if (day_counter > D) begin
                                state <= OUTPUT;
                            end
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                    
                    // Safety counter
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_mask <= infected_mask;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule