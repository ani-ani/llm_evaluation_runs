module connected_trees_max_component (
    input clk,
    input rst_n,
    input start,
    input [7:0] h [0:255],
    input [7:0] v [0:255],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_T = 3'd1;
    localparam [2:0] COMPUTE_HEIGHTS = 3'd2;
    localparam [2:0] BUILD_GRAPH = 3'd3;
    localparam [2:0] FIND_COMPONENTS = 3'd4;
    localparam [2:0] UPDATE_RESULT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] t;
    reg [7:0] idx;
    reg [7:0] curr_height [0:255];
    reg visited [0:255];
    reg [7:0] max_size, curr_size;
    reg [15:0] queue [0:255];  // BFS queue: node index (0-255)
    reg [7:0] q_head, q_tail;
    reg [7:0] node_id;
    reg processing;  // Flag to continue component processing
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;  // Safe upper bound

    // Neighbors calculation registers
    reg [7:0] neighbor_idx;
    reg [7:0] neighbor_count;
    reg [7:0] row, col;

    integer i;

    // Combinational logic for neighbor indices
    always @(*) begin
        row = node_id[7:4];  // Upper 4 bits for row (0-15)
        col = node_id[3:0];  // Lower 4 bits for col (0-15)
        
        // Default neighbor_idx to node_id (will be overwritten)
        neighbor_idx = node_id;
        case (neighbor_count)
            0: begin  // Up neighbor
                if (row > 0) neighbor_idx = node_id - 8'd16;
                else neighbor_idx = 8'd255;  // Invalid
            end
            1: begin  // Down neighbor
                if (row < 15) neighbor_idx = node_id + 8'd16;
                else neighbor_idx = 8'd255;  // Invalid
            end
            2: begin  // Left neighbor
                if (col > 0) neighbor_idx = node_id - 8'd1;
                else neighbor_idx = 8'd255;  // Invalid
            end
            3: begin  // Right neighbor
                if (col < 15) neighbor_idx = node_id + 8'd1;
                else neighbor_idx = 8'd255;  // Invalid
            end
            default: neighbor_idx = 8'd255;
        endcase
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            t <= 8'd0;
            idx <= 8'd0;
            max_size <= 8'd0;
            curr_size <= 8'd0;
            q_head <= 8'd0;
            q_tail <= 8'd0;
            node_id <= 8'd0;
            neighbor_count <= 8'd0;
            cycle_count <= 8'd0;
            processing <= 1'b0;
            // Initialize arrays
            for (i = 0; i < 256; i = i + 1) begin
                curr_height[i] <= 8'd0;
                visited[i] <= 1'b0;
                queue[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    t <= 8'd0;
                    max_size <= 8'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_T;
                    end
                end

                COMPUTE_T: begin
                    if (t < 8'd256) begin
                        state <= COMPUTE_HEIGHTS;
                        idx <= 8'd0;
                    end else begin
                        state <= FINISH;
                    end
                end

                COMPUTE_HEIGHTS: begin
                    if (idx < 8'd256) begin
                        // Compute height at time t (h + v*t)
                        // Overflow wraps naturally in Verilog
                        curr_height[idx] <= h[idx] + (v[idx] * t);
                        idx <= idx + 8'd1;
                    end else begin
                        state <= BUILD_GRAPH;
                        idx <= 8'd0;
                        // Reset visited array
                        for (i = 0; i < 256; i = i + 1) begin
                            visited[i] <= 1'b0;
                        end
                    end
                end

                BUILD_GRAPH: begin
                    // Find next unvisited node
                    if (idx < 8'd256) begin
                        if (!visited[idx]) begin
                            // Start BFS from this node
                            state <= FIND_COMPONENTS;
                            node_id <= idx;
                            q_head <= 8'd0;
                            q_tail <= 8'd1;
                            queue[0] <= {8'd0, idx};  // Pack with node index
                            visited[idx] <= 1'b1;
                            curr_size <= 8'd1;
                            neighbor_count <= 8'd0;
                            processing <= 1'b1;
                        end else begin
                            idx <= idx + 8'd1;
                        end
                    end else begin
                        state <= UPDATE_RESULT;
                    end
                end

                FIND_COMPONENTS: begin
                    if (processing && q_head < q_tail) begin
                        // Process neighbor
                        if (neighbor_count < 4) begin
                            // Check if neighbor is valid and unvisited
                            if (neighbor_idx < 8'd255 && !visited[neighbor_idx]) begin
                                // Check if heights match
                                if (curr_height[neighbor_idx] == curr_height[queue[q_head]]) begin
                                    visited[neighbor_idx] <= 1'b1;
                                    queue[q_tail] <= {8'd0, neighbor_idx};
                                    q_tail <= q_tail + 8'd1;
                                    curr_size <= curr_size + 8'd1;
                                end
                            end
                            neighbor_count <= neighbor_count + 8'd1;
                        end else begin
                            // Move to next node in queue
                            q_head <= q_head + 8'd1;
                            neighbor_count <= 8'd0;
                        end
                        
                        // Check if BFS complete
                        if (q_head >= q_tail || (q_head == q_tail - 8'd1 && neighbor_count == 4)) begin
                            if (q_head >= q_tail) begin
                                // Finished component, update max
                                if (curr_size > max_size) begin
                                    max_size <= curr_size;
                                end
                                state <= BUILD_GRAPH;
                                processing <= 1'b0;
                                idx <= idx + 8'd1;
                            end else if (neighbor_count == 4) begin
                                q_head <= q_head + 8'd1;
                            end
                        end
                    end else begin
                        state <= BUILD_GRAPH;
                        processing <= 1'b0;
                        idx <= idx + 8'd1;
                    end
                end

                UPDATE_RESULT: begin
                    t <= t + 8'd1;
                    state <= COMPUTE_T;
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= max_size;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Cycle counter for safety
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                    done <= 1'b1;
                    result <= max_size;
                end
            end
        end
    end

endmodule