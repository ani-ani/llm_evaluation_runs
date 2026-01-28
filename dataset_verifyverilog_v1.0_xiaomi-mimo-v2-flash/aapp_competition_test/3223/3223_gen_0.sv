module forest_generator(
    input clk,
    input rst_n,
    input start,
    input [3:0] V,
    input [7:0] deg [0:15],
    output reg done,
    output reg possible,
    output reg [3:0] edges_a [0:14],
    output reg [3:0] edges_b [0:14],
    output reg [3:0] edge_count
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] VALIDATE    = 3'd1;
    localparam [2:0] SORT_DEGS   = 3'd2;
    localparam [2:0] GEN_EDGES   = 3'd3;
    localparam [2:0] CHECK_CYCLE = 3'd4;
    localparam [2:0] DONE_STATE  = 3'd5;

    reg [2:0] state, next_state;
    
    // Internal registers for validation
    reg [8:0] sum_deg;
    reg [7:0] max_deg;
    reg [3:0] non_zero_count;
    reg [7:0] forest_limit;
    reg valid_flag;
    reg [3:0] i, j, k, idx;
    
    // Sorting registers
    reg [3:0] sorted_idx [0:15];
    reg [7:0] sorted_deg [0:15];
    reg [3:0] swap_idx;
    reg [7:0] swap_deg;
    reg sort_done;
    reg [3:0] sort_pass;
    
    // Edge generation registers
    reg [3:0] current_node;
    reg [3:0] next_node;
    reg [7:0] remaining_deg [0:15];
    reg [3:0] edge_ptr;
    reg [3:0] a_idx, b_idx;
    reg gen_done;
    
    // Cycle detection registers
    reg [15:0] visited_mask;
    reg [15:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] bfs_node, bfs_neighbor;
    reg [3:0] bfs_temp_idx;
    reg cycle_found;
    reg [3:0] bfs_depth;
    reg [15:0] temp_edge_a, temp_edge_b;
    reg [3:0] temp_edge_count;
    
    // Adjacency matrix for cycle check
    reg [15:0] adj [0:15];
    
    // Cycle counter to prevent timeout
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            possible <= 1'b0;
            edge_count <= 4'd0;
            cycle_counter <= 8'd0;
            
            // Initialize all arrays
            for (i = 0; i < 15; i = i + 1) begin
                edges_a[i] <= 4'd0;
                edges_b[i] <= 4'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                sorted_idx[i] <= 4'd0;
                sorted_deg[i] <= 8'd0;
                remaining_deg[i] <= 8'd0;
                adj[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            // Increment cycle counter (except in IDLE when not starting)
            if (state != IDLE || start) begin
                if (cycle_counter < MAX_CYCLES) begin
                    cycle_counter <= cycle_counter + 8'd1;
                end
            end
            
            case (state)
                IDLE: begin
                    if (start) begin
                        cycle_counter <= 8'd0;
                    end
                end
                
                VALIDATE: begin
                    if (i == 0) begin
                        sum_deg <= 9'd0;
                        max_deg <= 8'd0;
                        non_zero_count <= 4'd0;
                        valid_flag <= 1'b1;
                    end else if (i <= V && valid_flag) begin
                        sum_deg <= sum_deg + deg[i-1];
                        if (deg[i-1] > max_deg) begin
                            max_deg <= deg[i-1];
                        end
                        if (deg[i-1] != 0) begin
                            non_zero_count <= non_zero_count + 4'd1;
                        end
                    end else if (i == V + 1 && valid_flag) begin
                        // Check conditions
                        if (sum_deg[0] != 1'b0) begin // Even sum
                            valid_flag <= 1'b0;
                        end
                        if (max_deg > V - 4'd1 && V > 4'd1) begin
                            valid_flag <= 1'b0;
                        end
                        if (non_zero_count == 4'd0 && V > 4'd1) begin
                            valid_flag <= 1'b0;
                        end
                        forest_limit <= (V - non_zero_count) << 1;
                    end
                end
                
                SORT_DEGS: begin
                    // Bubble sort initialization
                    if (i == 0 && j == 0) begin
                        for (k = 0; k < 16; k = k + 1) begin
                            sorted_idx[k] <= k;
                            if (k < V) begin
                                sorted_deg[k] <= deg[k];
                            end else begin
                                sorted_deg[k] <= 8'd0;
                            end
                        end
                        sort_pass <= V - 4'd1;
                    end
                    
                    // Bubble sort pass
                    if (sort_pass > 4'd0 && j < sort_pass) begin
                        if (sorted_deg[j] < sorted_deg[j+1]) begin
                            // Swap
                            swap_deg <= sorted_deg[j];
                            sorted_deg[j] <= sorted_deg[j+1];
                            sorted_deg[j+1] <= swap_deg;
                            swap_idx <= sorted_idx[j];
                            sorted_idx[j] <= sorted_idx[j+1];
                            sorted_idx[j+1] <= swap_idx;
                        end
                    end
                end
                
                GEN_EDGES: begin
                    if (edge_ptr == 0) begin
                        // Initialize remaining degrees
                        for (k = 0; k < V; k = k + 1) begin
                            remaining_deg[k] <= sorted_deg[k];
                        end
                        edge_ptr <= 4'd1;
                    end else if (edge_ptr <= V) begin
                        // Pair node with highest degree
                        if (remaining_deg[edge_ptr-1] > 8'd0) begin
                            // Find partner (from start of list)
                            if (next_node == 0 && remaining_deg[edge_ptr-1] > 0) begin
                                for (k = 0; k < V; k = k + 1) begin
                                    if (k != (edge_ptr-1) && remaining_deg[k] > 0) begin
                                        next_node <= k + 4'd1;
                                        remaining_deg[k] <= remaining_deg[k] - 8'd1;
                                        remaining_deg[edge_ptr-1] <= remaining_deg[edge_ptr-1] - 8'd1;
                                        edges_a[edge_count] <= sorted_idx[edge_ptr-1] + 4'd1;
                                        edges_b[edge_count] <= sorted_idx[k] + 4'd1;
                                        edge_count <= edge_count + 4'd1;
                                        // Update adjacency for cycle check
                                        adj[sorted_idx[edge_ptr-1]] <= adj[sorted_idx[edge_ptr-1]] | (1 << sorted_idx[k]);
                                        adj[sorted_idx[k]] <= adj[sorted_idx[k]] | (1 << sorted_idx[edge_ptr-1]);
                                        k <= V; // Exit loop
                                    end
                                end
                            end
                        end
                    end else begin
                        edge_ptr <= 4'd0;
                    end
                end
                
                CHECK_CYCLE: begin
                    if (i == 0) begin
                        // Check if sum of remaining degrees is valid
                        temp_edge_count <= edge_count;
                        cycle_found <= 1'b0;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        visited_mask <= 16'd0;
                    end else if (i <= V && !cycle_found) begin
                        // BFS to check for cycles (traverse graph)
                        if (queue_head == 0 && queue_tail == 0 && visited_mask == 0) begin
                            // Start BFS from node i-1
                            if (adj[i-1] != 16'd0) begin
                                visited_mask <= (1 << i);
                                queue[0] <= i-1;
                                queue_tail <= 4'd1;
                            end
                        end else if (queue_head < queue_tail) begin
                            // Dequeue
                            bfs_node <= queue[queue_head];
                            queue_head <= queue_head + 4'd1;
                            bfs_temp_idx <= 0;
                        end else if (bfs_temp_idx < V) begin
                            // Process neighbors
                            if (adj[bfs_node] & (1 << bfs_temp_idx)) begin
                                if (visited_mask & (1 << bfs_temp_idx)) begin
                                    // Already visited - cycle detected
                                    cycle_found <= 1'b1;
                                end else begin
                                    visited_mask <= visited_mask | (1 << bfs_temp_idx);
                                    if (queue_tail < 4'd16) begin
                                        queue[queue_tail] <= bfs_temp_idx;
                                        queue_tail <= queue_tail + 4'd1;
                                    end
                                end
                            end
                            bfs_temp_idx <= bfs_temp_idx + 4'd1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (valid_flag && sum_deg[8:1] <= forest_limit && !cycle_found && edge_count > 0) begin
                        possible <= 1'b1;
                    end else begin
                        possible <= 1'b0;
                        // Clear edges on failure
                        for (k = 0; k < 15; k = k + 1) begin
                            edges_a[k] <= 4'd0;
                            edges_b[k] <= 4'd0;
                        end
                        edge_count <= 4'd0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = VALIDATE;
                else next_state = IDLE;
            end
            
            VALIDATE: begin
                if (i > V && valid_flag) next_state = SORT_DEGS;
                else if (i > V && !valid_flag) next_state = DONE_STATE;
                else next_state = VALIDATE;
            end
            
            SORT_DEGS: begin
                if (sort_pass == 4'd0 || cycle_counter >= MAX_CYCLES) next_state = GEN_EDGES;
                else next_state = SORT_DEGS;
            end
            
            GEN_EDGES: begin
                if (edge_ptr > V || cycle_counter >= MAX_CYCLES) begin
                    next_state = CHECK_CYCLE;
                end else begin
                    next_state = GEN_EDGES;
                end
            end
            
            CHECK_CYCLE: begin
                if (i > V || cycle_counter >= MAX_CYCLES) next_state = DONE_STATE;
                else next_state = CHECK_CYCLE;
            end
            
            DONE_STATE: begin
                if (done) next_state = IDLE;
                else next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Control logic for counters and loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
        end else begin
            case (state)
                VALIDATE: begin
                    if (i <= V + 1) i <= i + 4'd1;
                    else i <= 4'd0;
                end
                
                SORT_DEGS: begin
                    if (sort_pass > 4'd0) begin
                        if (j < sort_pass) begin
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            sort_pass <= sort_pass - 4'd1;
                        end
                    end
                end
                
                GEN_EDGES: begin
                    if (edge_ptr <= V) begin
                        next_node <= 4'd0;
                    end
                end
                
                CHECK_CYCLE: begin
                    if (i <= V) i <= i + 4'd1;
                    else i <= 4'd0;
                end
                
                default: begin
                    i <= 4'd0;
                    j <= 4'd0;
                end
            endcase
        end
    end

endmodule