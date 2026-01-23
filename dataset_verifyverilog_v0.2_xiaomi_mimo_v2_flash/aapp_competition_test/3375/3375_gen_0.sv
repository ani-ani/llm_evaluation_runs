module count_unicyclic (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] num_vertices,
    input wire [2:0] num_edges,
    input wire [5:0] edge_addr,
    input wire [2:0] edge_v1,
    input wire [2:0] edge_v2,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Parameters
    parameter MOD = 32'd1000000001;
    
    // States
    localparam IDLE = 4'b0000;
    localparam LOAD_EDGES = 4'b0001;
    localparam PREPARE_ENUM = 4'b0010;
    localparam ENUMERATE = 4'b0011;
    localparam VERIFY_SUBSET = 4'b0100;
    localparam UPDATE_RESULT = 4'b0101;
    localparam DONE = 4'b0110;
    
    // Edge memory: up to 28 edges, each with 6 bits (3 bits per vertex)
    reg [5:0] edge_mem [0:27];
    reg [4:0] edge_count;
    
    // State registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Computation registers
    reg [4:0] target_v;
    reg [4:0] target_e;
    reg [7:0] valid_count;
    
    // Combination generation
    reg [27:0] current_mask;
    reg [27:0] max_mask;
    reg [5:0] edge_idx;
    reg [4:0] selected_count;
    reg [27:0] temp_mask;
    
    // Connectivity check
    reg [7:0] visited;
    reg [7:0] queue [0:7];
    reg [2:0] q_head;
    reg [2:0] q_tail;
    reg [2:0] current_vertex;
    reg connectivity_done;
    reg connectivity_valid;
    reg [2:0] neighbor_idx;
    reg [2:0] neighbor_v1;
    reg [2:0] neighbor_v2;
    
    // Edge iteration
    reg [4:0] edge_iter;
    reg [27:0] edge_mask_bit;
    
    // Helper signals
    reg start_processing;
    reg computation_done;
    reg update_valid;
    
    integer i, j;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Main state machine
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_EDGES;
                end
            end
            
            LOAD_EDGES: begin
                if (edge_count >= num_edges) begin
                    next_state = PREPARE_ENUM;
                end
            end
            
            PREPARE_ENUM: begin
                if (num_vertices >= 2 && num_edges >= num_vertices) begin
                    next_state = ENUMERATE;
                end else begin
                    next_state = DONE;
                end
            end
            
            ENUMERATE: begin
                if (current_mask > max_mask) begin
                    next_state = DONE;
                end else begin
                    next_state = VERIFY_SUBSET;
                end
            end
            
            VERIFY_SUBSET: begin
                if (connectivity_done) begin
                    if (connectivity_valid) begin
                        next_state = UPDATE_RESULT;
                    end else begin
                        next_state = ENUMERATE;
                    end
                end
            end
            
            UPDATE_RESULT: begin
                next_state = ENUMERATE;
            end
            
            DONE: begin
                // Stay in done state until reset
            end
        endcase
    end
    
    // Output signals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 0;
                    done <= 0;
                    result <= 0;
                end
                
                LOAD_EDGES: begin
                    busy <= 1;
                    done <= 0;
                end
                
                PREPARE_ENUM: begin
                    busy <= 1;
                    done <= 0;
                end
                
                ENUMERATE: begin
                    busy <= 1;
                    done <= 0;
                end
                
                VERIFY_SUBSET: begin
                    busy <= 1;
                    done <= 0;
                end
                
                UPDATE_RESULT: begin
                    if (update_valid) begin
                        result <= (result + 1) % MOD;
                    end
                end
                
                DONE: begin
                    busy <= 0;
                    done <= 1;
                end
            endcase
        end
    end
    
    // Edge loading logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_count <= 0;
        end else if (state == LOAD_EDGES) begin
            if (edge_addr < 28 && edge_v1 != 0 && edge_v2 != 0 && edge_addr == edge_count) begin
                edge_mem[edge_addr] <= {edge_v1, edge_v2};
                edge_count <= edge_count + 1;
            end
        end else if (state == IDLE) begin
            edge_count <= 0;
        end
    end
    
    // Prepare enumerate - calculate targets
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_v <= 0;
            target_e <= 0;
            current_mask <= 0;
            max_mask <= 0;
        end else if (state == PREPARE_ENUM) begin
            target_v <= num_vertices;
            target_e <= num_edges;
            current_mask <= 1; // Start with first edge selected
            // Max mask: select exactly V edges from E edges
            // Simple approximation: use bitmask of E bits, filtered by count
            max_mask <= (1 << num_edges) - 1;
        end
    end
    
    // Combination generation with pruning
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_mask <= 0;
            selected_count <= 0;
        end else if (state == ENUMERATE) begin
            // Find next valid mask with exactly target_v edges
            do begin
                current_mask <= current_mask + 1;
                // Count bits
                selected_count <= count_bits(current_mask + 1);
            end while (selected_count != target_v && current_mask < max_mask);
        end else if (state == PREPARE_ENUM) begin
            selected_count <= 0;
        end
    end
    
    // Connectivity check - stateful BFS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            connectivity_done <= 0;
            connectivity_valid <= 0;
            visited <= 0;
            q_head <= 0;
            q_tail <= 0;
            edge_iter <= 0;
        end else if (state == VERIFY_SUBSET) begin
            if (!connectivity_done) begin
                // Initialize BFS
                if (edge_iter == 0) begin
                    visited <= (1 << (num_vertices - 1)); // Start from vertex 1
                    queue[0] <= 1;
                    q_head <= 0;
                    q_tail <= 1;
                    edge_iter <= 1;
                end else if (edge_iter == 1) begin
                    // Process BFS
                    if (q_head < q_tail) begin
                        current_vertex <= queue[q_head];
                        q_head <= q_head + 1;
                        edge_iter <= 2;
                    end else begin
                        // BFS complete, check if all visited
                        connectivity_done <= 1;
                        connectivity_valid <= (visited == ((1 << num_vertices) - 1));
                    end
                end else if (edge_iter == 2) begin
                    // Check all edges for neighbors
                    if (edge_idx < target_e) begin
                        if (current_mask[edge_idx]) begin
                            neighbor_v1 <= edge_mem[edge_idx][5:3];
                            neighbor_v2 <= edge_mem[edge_idx][2:0];
                        end
                        edge_idx <= edge_idx + 1;
                        edge_iter <= 3;
                    end else begin
                        edge_idx <= 0;
                        edge_iter <= 1;
                    end
                end else if (edge_iter == 3) begin
                    // Add neighbors to queue
                    if (neighbor_v1 == current_vertex && !visited[neighbor_v2 - 1]) begin
                        queue[q_tail] <= neighbor_v2;
                        q_tail <= q_tail + 1;
                        visited[neighbor_v2 - 1] <= 1;
                    end else if (neighbor_v2 == current_vertex && !visited[neighbor_v1 - 1]) begin
                        queue[q_tail] <= neighbor_v1;
                        q_tail <= q_tail + 1;
                        visited[neighbor_v1 - 1] <= 1;
                    end
                    edge_iter <= 2;
                end
            end
        end else if (state != VERIFY_SUBSET) begin
            connectivity_done <= 0;
            edge_iter <= 0;
            edge_idx <= 0;
        end
    end
    
    // Update result validation
    always @(*) begin
        if (state == UPDATE_RESULT) begin
            update_valid = 1;
        end else begin
            update_valid = 0;
        end
    end
    
    // Helper function to count bits
    function [4:0] count_bits;
        input [27:0] mask;
        integer k;
        begin
            count_bits = 0;
            for (k = 0; k < target_e; k = k + 1) begin
                if (mask[k]) count_bits = count_bits + 1;
            end
        end
    endfunction

endmodule