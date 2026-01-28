module TimePathFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] start_hh,
    input wire [5:0] start_mm,
    input wire [4:0] target_hh,
    input wire [5:0] target_mm,
    output reg result_valid,
    output reg [3:0] result_len,
    output reg [10:0] result_timestamps [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BFS_INIT = 3'd1;
    localparam [2:0] BFS_RUN = 3'd2;
    localparam [2:0] PATH_RECONSTRUCT = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    reg [2:0] state, next_state;
    
    // BFS parameters
    localparam [10:0] MAX_NODES = 11'd1440;
    localparam [5:0] MAX_QUEUE = 6'd64;
    localparam [3:0] MAX_PATH = 4'd16;
    
    // Internal registers
    reg [10:0] start_idx, target_idx;
    reg [10:0] current_node, next_node;
    reg [10:0] queue [0:MAX_QUEUE-1];
    reg [5:0] queue_head, queue_tail;
    reg [10:0] parent [0:MAX_NODES-1];
    reg [10:0] visited [0:179]; // 1440 bits = 180 bytes
    reg [10:0] path [0:MAX_PATH-1];
    reg [3:0] path_len;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // Helper functions
    function [10:0] pack_time;
        input [4:0] hh;
        input [5:0] mm;
        pack_time = {hh, mm};
    endfunction
    
    function [4:0] unpack_hh;
        input [10:0] packed;
        unpack_hh = packed[10:6];
    endfunction
    
    function [5:0] unpack_mm;
        input [10:0] packed;
        unpack_mm = packed[5:0];
    endfunction
    
    function [10:0] time_to_idx;
        input [4:0] hh;
        input [5:0] mm;
        time_to_idx = hh * 6'd60 + mm;
    endfunction
    
    function [10:0] idx_to_time;
        input [10:0] idx;
        reg [4:0] hh;
        reg [5:0] mm;
        begin
            hh = idx / 6'd60;
            mm = idx % 6'd60;
            idx_to_time = {hh, mm};
        end
    endfunction
    
    function [10:0] increment_digit;
        input [10:0] time;
        input [1:0] digit;
        reg [4:0] hh;
        reg [5:0] mm;
        reg [3:0] h1, h0, m1, m0;
        begin
            hh = unpack_hh(time);
            mm = unpack_mm(time);
            h1 = hh[4:1];
            h0 = hh[0];
            m1 = mm[5:2];
            m0 = mm[1:0];
            
            case (digit)
                2'd0: h1 = (h1 + 1) % 4'd2; // h1: 0-2
                2'd1: h0 = (h0 + 1) % 4'd10; // h0: 0-9
                2'd2: m1 = (m1 + 1) % 4'd6; // m1: 0-5
                2'd3: m0 = (m0 + 1) % 4'd10; // m0: 0-9
            endcase
            
            hh = {h1, h0};
            mm = {m1, m0};
            
            // Validate time
            if (hh > 5'd23) hh = 5'd0;
            if (mm > 6'd59) mm = 6'd0;
            
            increment_digit = {hh, mm};
        end
    endfunction
    
    function [10:0] decrement_digit;
        input [10:0] time;
        input [1:0] digit;
        reg [4:0] hh;
        reg [5:0] mm;
        reg [3:0] h1, h0, m1, m0;
        begin
            hh = unpack_hh(time);
            mm = unpack_mm(time);
            h1 = hh[4:1];
            h0 = hh[0];
            m1 = mm[5:2];
            m0 = mm[1:0];
            
            case (digit)
                2'd0: h1 = (h1 - 1 + 4'd2) % 4'd2; // h1: 0-2
                2'd1: h0 = (h0 - 1 + 4'd10) % 4'd10; // h0: 0-9
                2'd2: m1 = (m1 - 1 + 4'd6) % 4'd6; // m1: 0-5
                2'd3: m0 = (m0 - 1 + 4'd10) % 4'd10; // m0: 0-9
            endcase
            
            hh = {h1, h0};
            mm = {m1, m0};
            
            // Validate time
            if (hh > 5'd23) hh = 5'd0;
            if (mm > 6'd59) mm = 6'd0;
            
            decrement_digit = {hh, mm};
        end
    endfunction
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_len <= 4'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 180; i = i + 1) begin
                visited[i] <= 11'd0;
            end
            
            for (i = 0; i < 16; i = i + 1) begin
                result_timestamps[i] <= 11'd0;
            end
            
            for (i = 0; i < 64; i = i + 1) begin
                queue[i] <= 11'd0;
            end
            
            for (i = 0; i < 1440; i = i + 1) begin
                parent[i] <= 11'd0;
            end
            
            for (i = 0; i < 16; i = i + 1) begin
                path[i] <= 11'd0;
            end
            
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            path_len <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= BFS_INIT;
                    end
                end
                
                BFS_INIT: begin
                    // Initialize BFS
                    start_idx <= time_to_idx(start_hh, start_mm);
                    target_idx <= time_to_idx(target_hh, target_mm);
                    
                    // Reset visited array
                    integer i;
                    for (i = 0; i < 180; i = i + 1) begin
                        visited[i] <= 11'd0;
                    end
                    
                    // Reset queue
                    queue_head <= 6'd0;
                    queue_tail <= 6'd0;
                    
                    // Reset parent array
                    for (i = 0; i < 1440; i = i + 1) begin
                        parent[i] <= 11'd0;
                    end
                    
                    // Mark start node as visited
                    visited[start_idx / 11'd8] <= visited[start_idx / 11'd8] | (11'd1 << (start_idx % 11'd8));
                    
                    // Enqueue start node
                    queue[queue_tail] <= start_idx;
                    queue_tail <= queue_tail + 6'd1;
                    
                    next_state <= BFS_RUN;
                end
                
                BFS_RUN: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else if (queue_head == queue_tail) begin
                        // Queue empty - no path found
                        next_state <= IDLE;
                    end else begin
                        // Dequeue current node
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 6'd1;
                        
                        // Check if target reached
                        if (current_node == target_idx) begin
                            next_state <= PATH_RECONSTRUCT;
                        end else begin
                            // Generate neighbors
                            integer i;
                            reg [10:0] neighbor;
                            reg [10:0] neighbor_idx;
                            
                            for (i = 0; i < 4; i = i + 1) begin
                                // Increment digit
                                neighbor <= increment_digit(idx_to_time(current_node), i);
                                neighbor_idx <= time_to_idx(unpack_hh(neighbor), unpack_mm(neighbor));
                                
                                // Check if visited
                                if (!(visited[neighbor_idx / 11'd8] & (11'd1 << (neighbor_idx % 11'd8)))) begin
                                    visited[neighbor_idx / 11'd8] <= visited[neighbor_idx / 11'd8] | (11'd1 << (neighbor_idx % 11'd8));
                                    parent[neighbor_idx] <= current_node;
                                    
                                    // Enqueue
                                    if (queue_tail < MAX_QUEUE) begin
                                        queue[queue_tail] <= neighbor_idx;
                                        queue_tail <= queue_tail + 6'd1;
                                    end
                                end
                                
                                // Decrement digit
                                neighbor <= decrement_digit(idx_to_time(current_node), i);
                                neighbor_idx <= time_to_idx(unpack_hh(neighbor), unpack_mm(neighbor));
                                
                                // Check if visited
                                if (!(visited[neighbor_idx / 11'd8] & (11'd1 << (neighbor_idx % 11'd8)))) begin
                                    visited[neighbor_idx / 11'd8] <= visited[neighbor_idx / 11'd8] | (11'd1 << (neighbor_idx % 11'd8));
                                    parent[neighbor_idx] <= current_node;
                                    
                                    // Enqueue
                                    if (queue_tail < MAX_QUEUE) begin
                                        queue[queue_tail] <= neighbor_idx;
                                        queue_tail <= queue_tail + 6'd1;
                                    end
                                end
                            end
                        end
                    end
                end
                
                PATH_RECONSTRUCT: begin
                    // Reconstruct path from target to start
                    integer i;
                    reg [10:0] current;
                    
                    current <= target_idx;
                    path_len <= 4'd0;
                    
                    // Clear path array
                    for (i = 0; i < 16; i = i + 1) begin
                        path[i] <= 11'd0;
                    end
                    
                    // Build path in reverse
                    while (current != start_idx && path_len < MAX_PATH) begin
                        path[path_len] <= idx_to_time(current);
                        path_len <= path_len + 4'd1;
                        current <= parent[current];
                    end
                    
                    // Add start node
                    if (path_len < MAX_PATH) begin
                        path[path_len] <= idx_to_time(start_idx);
                        path_len <= path_len + 4'd1;
                    end
                    
                    next_state <= OUTPUT;
                end
                
                OUTPUT: begin
                    // Output path in correct order
                    integer i;
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < path_len) begin
                            result_timestamps[i] <= path[path_len - 1 - i];
                        end else begin
                            result_timestamps[i] <= 11'd0;
                        end
                    end
                    
                    result_len <= path_len;
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Default assignments for outputs
    always @(*) begin
        if (state == OUTPUT) begin
            result_valid = 1'b1;
            done = 1'b1;
        end else begin
            result_valid = 1'b0;
            done = 1'b0;
        end
    end

endmodule