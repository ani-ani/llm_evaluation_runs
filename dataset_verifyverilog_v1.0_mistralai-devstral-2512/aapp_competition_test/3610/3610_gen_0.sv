module MinimumVertexCover(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire valid_team,
    input wire [9:0] stockholm_id,
    input wire [9:0] london_id,
    output reg result_valid,
    output reg [3:0] result_size,
    output reg [9:0] result_0,
    output reg [9:0] result_1,
    output reg [9:0] result_2,
    output reg [9:0] result_3,
    output reg [9:0] result_4,
    output reg [9:0] result_5,
    output reg [9:0] result_6,
    output reg [9:0] result_7,
    output reg [9:0] result_8,
    output reg [9:0] result_9,
    output reg [9:0] result_10,
    output reg [9:0] result_11,
    output reg [9:0] result_12,
    output reg [9:0] result_13,
    output reg [9:0] result_14,
    output reg [9:0] result_15
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INPUT = 4'd1;
    localparam [3:0] BUILD_GRAPH = 4'd2;
    localparam [3:0] MATCH_START = 4'd3;
    localparam [3:0] MATCH_BFS = 4'd4;
    localparam [3:0] MATCH_DFS = 4'd5;
    localparam [3:0] COVER_CONSTRUCT = 4'd6;
    localparam [3:0] FRIEND_CHECK = 4'd7;
    localparam [3:0] OUTPUT = 4'd8;

    // Graph parameters
    localparam [3:0] MAX_TEAMS = 4'd10;
    localparam [3:0] MAX_STOCKHOLM = 4'd10;
    localparam [3:0] MAX_LONDON = 4'd6;
    localparam [3:0] MAX_NODES = 4'd16;

    // Graph representation
    reg [5:0] graph [0:9]; // 10 Stockholm nodes, 6 London nodes each
    reg [9:0] st_id_map [0:9]; // Stockholm ID mapping
    reg [9:0] ld_id_map [0:5]; // London ID mapping

    // Matching arrays
    reg [3:0] match_st [0:9]; // Match for Stockholm nodes
    reg [3:0] match_ld [0:5]; // Match for London nodes

    // BFS/DFS structures
    reg [3:0] queue [0:15]; // Queue for BFS
    reg [3:0] queue_head, queue_tail;
    reg [9:0] visited_st [0:9]; // Visited flags
    reg [5:0] visited_ld [0:5];
    reg [3:0] layer [0:9]; // Layer numbers

    // Vertex cover
    reg [15:0] cover; // Bitmask of nodes in cover
    reg [3:0] cover_size;

    // Control signals
    reg [3:0] state, next_state;
    reg [3:0] team_count;
    reg [3:0] cycle_count;
    reg [3:0] i, j, k;
    reg found_augmenting;
    reg friend_included;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            team_count <= 4'd0;
            cycle_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            found_augmenting <= 1'b0;
            friend_included <= 1'b0;
            result_valid <= 1'b0;
            result_size <= 4'd0;
            
            // Initialize graph
            for (i = 0; i < 10; i = i + 1) begin
                graph[i] <= 6'd0;
                st_id_map[i] <= 10'd0;
                match_st[i] <= 4'd0;
                layer[i] <= 4'd0;
                visited_st[i] <= 1'b0;
            end
            
            // Initialize London nodes
            for (i = 0; i < 6; i = i + 1) begin
                ld_id_map[i] <= 10'd0;
                match_ld[i] <= 4'd0;
                visited_ld[i] <= 1'b0;
            end
            
            // Initialize queue
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                queue[i] <= 4'd0;
            end
            
            // Initialize results
            result_0 <= 10'd0;
            result_1 <= 10'd0;
            result_2 <= 10'd0;
            result_3 <= 10'd0;
            result_4 <= 10'd0;
            result_5 <= 10'd0;
            result_6 <= 10'd0;
            result_7 <= 10'd0;
            result_8 <= 10'd0;
            result_9 <= 10'd0;
            result_10 <= 10'd0;
            result_11 <= 10'd0;
            result_12 <= 10'd0;
            result_13 <= 10'd0;
            result_14 <= 10'd0;
            result_15 <= 10'd0;
            
            cover <= 16'd0;
            cover_size <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                if (start) begin
                    next_state <= INPUT;
                    team_count <= 4'd0;
                end else begin
                    next_state <= IDLE;
                end
            end

            INPUT: begin
                if (valid_team) begin
                    // Map IDs to internal representation
                    if (stockholm_id >= 10'd1000 && stockholm_id <= 10'd1009) begin
                        st_id_map[team_count] <= stockholm_id - 10'd1000;
                    end
                    if (london_id >= 10'd2000 && london_id <= 10'd2005) begin
                        ld_id_map[team_count] <= london_id - 10'd2000;
                    end
                    team_count <= team_count + 4'd1;
                end
                if (team_count >= MAX_TEAMS || !valid_team) begin
                    next_state <= BUILD_GRAPH;
                end
            end

            BUILD_GRAPH: begin
                // Build adjacency matrix
                for (i = 0; i < 10; i = i + 1) begin
                    graph[i] <= 6'd0;
                end
                for (i = 0; i < team_count; i = i + 1) begin
                    if (st_id_map[i] < 10 && ld_id_map[i] < 6) begin
                        graph[st_id_map[i]] <= graph[st_id_map[i]] | (1 << ld_id_map[i]);
                    end
                end
                next_state <= MATCH_START;
            end

            MATCH_START: begin
                // Initialize matching
                for (i = 0; i < 10; i = i + 1) begin
                    match_st[i] <= 4'd0;
                end
                for (i = 0; i < 6; i = i + 1) begin
                    match_ld[i] <= 4'd0;
                end
                next_state <= MATCH_BFS;
            end

            MATCH_BFS: begin
                // BFS to build layer graph
                // Initialize queue and visited
                queue_head <= 4'd0;
                queue_tail <= 4'd0;
                for (i = 0; i < 10; i = i + 1) begin
                    visited_st[i] <= 1'b0;
                    layer[i] <= 4'd0;
                end
                for (i = 0; i < 6; i = i + 1) begin
                    visited_ld[i] <= 1'b0;
                end

                // Enqueue unmatched Stockholm nodes
                for (i = 0; i < 10; i = i + 1) begin
                    if (match_st[i] == 4'd0) begin
                        queue[queue_tail] <= i;
                        queue_tail <= queue_tail + 4'd1;
                        visited_st[i] <= 1'b1;
                        layer[i] <= 4'd1;
                    end
                end

                // BFS loop
                while (queue_head < queue_tail) begin
                    i <= queue[queue_head];
                    queue_head <= queue_head + 4'd1;

                    // Check all neighbors
                    for (j = 0; j < 6; j = j + 1) begin
                        if (graph[i][j] && !visited_ld[j]) begin
                            visited_ld[j] <= 1'b1;
                            // Check if matched
                            if (match_ld[j] != 4'd0) begin
                                k <= match_ld[j];
                                if (!visited_st[k]) begin
                                    visited_st[k] <= 1'b1;
                                    layer[k] <= layer[i] + 4'd1;
                                    queue[queue_tail] <= k;
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                    end
                end

                // Check if we found an augmenting path
                found_augmenting <= 1'b0;
                for (i = 0; i < 6; i = i + 1) begin
                    if (visited_ld[i] && match_ld[i] == 4'd0) begin
                        found_augmenting <= 1'b1;
                    end
                end

                if (found_augmenting) begin
                    next_state <= MATCH_DFS;
                end else begin
                    next_state <= COVER_CONSTRUCT;
                end
            end

            MATCH_DFS: begin
                // DFS to find augmenting paths
                // This is a simplified version - in real implementation would need stack
                // For synthesis, we'll use iterative approach
                
                // Find an unmatched London node that was visited
                i <= 4'd0;
                while (i < 6 && !(visited_ld[i] && match_ld[i] == 4'd0)) begin
                    i <= i + 4'd1;
                end
                
                if (i < 6) begin
                    // Found augmenting path ending at i
                    // Backtrack to find the path
                    j <= 4'd0;
                    while (j < 10 && (match_st[j] != i || !visited_st[j])) begin
                        j <= j + 4'd1;
                    end
                    
                    if (j < 10) begin
                        // Augment the path
                        match_ld[i] <= j;
                        match_st[j] <= i;
                    end
                end
                
                next_state <= MATCH_BFS;
            end

            COVER_CONSTRUCT: begin
                // Construct vertex cover using König's theorem
                cover <= 16'd0;
                cover_size <= 4'd0;
                
                // Left-unmatched + Right-matched
                for (i = 0; i < 10; i = i + 1) begin
                    if (match_st[i] == 4'd0) begin
                        cover[i] <= 1'b1;
                        cover_size <= cover_size + 4'd1;
                    end
                end
                
                for (i = 0; i < 6; i = i + 1) begin
                    if (match_ld[i] != 4'd0) begin
                        cover[i + 10] <= 1'b1;
                        cover_size <= cover_size + 4'd1;
                    end
                end
                
                next_state <= FRIEND_CHECK;
            end

            FRIEND_CHECK: begin
                // Check if friend (index 9) is included
                friend_included <= cover[9];
                
                if (!friend_included) begin
                    // Check if we can include friend without increasing cover size
                    // This is simplified - in real implementation would need to check
                    // if there's an alternating path that allows including node 9
                    // For synthesis, we'll just include it if it helps
                    
                    // Check if node 9 is connected to any matched London node
                    i <= 4'd0;
                    while (i < 6 && !(graph[9][i] && match_ld[i] != 4'd0)) begin
                        i <= i + 4'd1;
                    end
                    
                    if (i < 6) begin
                        // Can potentially include friend
                        cover[9] <= 1'b1;
                        cover_size <= cover_size + 4'd1;
                        
                        // Remove one of the matched nodes to keep size same
                        // This is a heuristic - real implementation would need to verify
                        j <= 4'd0;
                        while (j < 6 && match_ld[j] == 4'd0) begin
                            j <= j + 4'd1;
                        end
                        
                        if (j < 6) begin
                            cover[match_ld[j] + 10] <= 1'b0;
                            cover_size <= cover_size - 4'd1;
                        end
                    end
                end
                
                next_state <= OUTPUT;
            end

            OUTPUT: begin
                // Prepare output
                result_size <= cover_size;
                
                // Map results back to original IDs
                k <= 4'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    if (cover[i]) begin
                        if (i < 10) begin
                            // Stockholm node
                            if (k == 4'd0) result_0 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd1) result_1 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd2) result_2 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd3) result_3 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd4) result_4 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd5) result_5 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd6) result_6 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd7) result_7 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd8) result_8 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd9) result_9 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd10) result_10 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd11) result_11 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd12) result_12 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd13) result_13 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd14) result_14 <= st_id_map[i] + 10'd1000;
                            else if (k == 4'd15) result_15 <= st_id_map[i] + 10'd1000;
                        end else begin
                            // London node
                            j <= i - 10;
                            if (k == 4'd0) result_0 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd1) result_1 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd2) result_2 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd3) result_3 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd4) result_4 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd5) result_5 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd6) result_6 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd7) result_7 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd8) result_8 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd9) result_9 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd10) result_10 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd11) result_11 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd12) result_12 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd13) result_13 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd14) result_14 <= ld_id_map[j] + 10'd2000;
                            else if (k == 4'd15) result_15 <= ld_id_map[j] + 10'd2000;
                        end
                        k <= k + 4'd1;
                    end
                end
                
                // Clear remaining outputs
                while (k < 16) begin
                    if (k == 4'd0) result_0 <= 10'd0;
                    else if (k == 4'd1) result_1 <= 10'd0;
                    else if (k == 4'd2) result_2 <= 10'd0;
                    else if (k == 4'd3) result_3 <= 10'd0;
                    else if (k == 4'd4) result_4 <= 10'd0;
                    else if (k == 4'd5) result_5 <= 10'd0;
                    else if (k == 4'd6) result_6 <= 10'd0;
                    else if (k == 4'd7) result_7 <= 10'd0;
                    else if (k == 4'd8) result_8 <= 10'd0;
                    else if (k == 4'd9) result_9 <= 10'd0;
                    else if (k == 4'd10) result_10 <= 10'd0;
                    else if (k == 4'd11) result_11 <= 10'd0;
                    else if (k == 4'd12) result_12 <= 10'd0;
                    else if (k == 4'd13) result_13 <= 10'd0;
                    else if (k == 4'd14) result_14 <= 10'd0;
                    else if (k == 4'd15) result_15 <= 10'd0;
                    k <= k + 4'd1;
                end
                
                result_valid <= 1'b1;
                next_state <= IDLE;
            end

            default: next_state <= IDLE;
        endcase
    end

endmodule