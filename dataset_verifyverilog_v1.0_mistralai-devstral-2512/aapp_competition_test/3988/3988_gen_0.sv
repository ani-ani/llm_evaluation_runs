module MixedGraphReach(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] m_in,
    input [3:0] s_in,
    input [15:0] edge_type,
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    output reg [4:0] max_reach,
    output reg [4:0] min_reach,
    output reg [15:0] max_orient,
    output reg [15:0] min_orient,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LATCH     = 3'd1;
    localparam [2:0] MAX_BFS   = 3'd2;
    localparam [2:0] MIN_BFS   = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Input registers
    reg [3:0] n_reg, m_reg, s_reg;
    reg [15:0] edge_type_reg;
    reg [3:0] edge_u_reg [0:15];
    reg [3:0] edge_v_reg [0:15];

    // BFS/DFS variables
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [15:0] visited_max, visited_min;
    reg [3:0] current_node;
    reg [3:0] edge_index;
    reg [3:0] cycle_count;

    // Orientation tracking
    reg [15:0] max_orient_reg, min_orient_reg;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            max_reach <= 5'd0;
            min_reach <= 5'd0;
            max_orient <= 16'd0;
            min_orient <= 16'd0;
            n_reg <= 4'd0;
            m_reg <= 4'd0;
            s_reg <= 4'd0;
            edge_type_reg <= 16'd0;
            
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                edge_u_reg[i] <= 4'd0;
                edge_v_reg[i] <= 4'd0;
                queue[i] <= 4'd0;
            end
            
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            visited_max <= 16'd0;
            visited_min <= 16'd0;
            current_node <= 4'd0;
            edge_index <= 4'd0;
            cycle_count <= 4'd0;
            max_orient_reg <= 16'd0;
            min_orient_reg <= 16'd0;
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
                    next_state = LATCH;
                end
            end

            LATCH: begin
                next_state = MAX_BFS;
            end

            MAX_BFS: begin
                if (cycle_count >= 16'd1024) begin
                    next_state = MIN_BFS;
                end else if (queue_head == queue_tail) begin
                    next_state = MIN_BFS;
                end
            end

            MIN_BFS: begin
                if (cycle_count >= 16'd1024) begin
                    next_state = OUTPUT;
                end else if (queue_head == queue_tail) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Latch inputs
    always @(posedge clk) begin
        if (state == LATCH) begin
            n_reg <= n_in;
            m_reg <= m_in;
            s_reg <= s_in;
            edge_type_reg <= edge_type;
            
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                edge_u_reg[i] <= edge_u[i];
                edge_v_reg[i] <= edge_v[i];
            end
            
            // Initialize for max BFS
            visited_max <= 16'd0;
            visited_max[s_reg] <= 1'b1;
            queue[0] <= s_reg;
            queue_head <= 4'd0;
            queue_tail <= 4'd1;
            max_orient_reg <= 16'd0;
            max_reach <= 5'd1;
            
            // Initialize for min BFS
            visited_min <= 16'd0;
            visited_min[s_reg] <= 1'b1;
            queue[0] <= s_reg;
            queue_head <= 4'd0;
            queue_tail <= 4'd1;
            min_orient_reg <= 16'd0;
            min_reach <= 5'd1;
            
            cycle_count <= 4'd0;
        end
    end

    // Max BFS processing
    always @(posedge clk) begin
        if (state == MAX_BFS) begin
            if (queue_head < queue_tail) begin
                current_node <= queue[queue_head];
                queue_head <= queue_head + 4'd1;
                
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    if (edge_type_reg[i] == 2'b01 || edge_type_reg[i] == 2'b10) begin
                        // Directed edge
                        if (edge_u_reg[i] == current_node && !visited_max[edge_v_reg[i]]) begin
                            visited_max[edge_v_reg[i]] <= 1'b1;
                            queue[queue_tail] <= edge_v_reg[i];
                            queue_tail <= queue_tail + 4'd1;
                            max_reach <= max_reach + 5'd1;
                        end
                    end else if (edge_type_reg[i] == 2'b11) begin
                        // Undirected edge - can traverse in either direction
                        if ((edge_u_reg[i] == current_node || edge_v_reg[i] == current_node) && 
                            !visited_max[edge_u_reg[i]] && !visited_max[edge_v_reg[i]]) begin
                            // Set orientation to allow traversal
                            if (edge_u_reg[i] == current_node) begin
                                max_orient_reg[i] <= 1'b1;  // u->v
                                if (!visited_max[edge_v_reg[i]]) begin
                                    visited_max[edge_v_reg[i]] <= 1'b1;
                                    queue[queue_tail] <= edge_v_reg[i];
                                    queue_tail <= queue_tail + 4'd1;
                                    max_reach <= max_reach + 5'd1;
                                end
                            end else begin
                                max_orient_reg[i] <= 1'b0;  // v->u
                                if (!visited_max[edge_u_reg[i]]) begin
                                    visited_max[edge_u_reg[i]] <= 1'b1;
                                    queue[queue_tail] <= edge_u_reg[i];
                                    queue_tail <= queue_tail + 4'd1;
                                    max_reach <= max_reach + 5'd1;
                                end
                            end
                        end
                    end
                end
            end
            cycle_count <= cycle_count + 4'd1;
        end
    end

    // Min BFS processing
    always @(posedge clk) begin
        if (state == MIN_BFS) begin
            if (queue_head < queue_tail) begin
                current_node <= queue[queue_head];
                queue_head <= queue_head + 4'd1;
                
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    if (edge_type_reg[i] == 2'b01) begin
                        // Directed edge
                        if (edge_u_reg[i] == current_node && !visited_min[edge_v_reg[i]]) begin
                            visited_min[edge_v_reg[i]] <= 1'b1;
                            queue[queue_tail] <= edge_v_reg[i];
                            queue_tail <= queue_tail + 4'd1;
                            min_reach <= min_reach + 5'd1;
                        end
                    end else if (edge_type_reg[i] == 2'b11) begin
                        // Undirected edge - only traverse if oriented away from s
                        // For min reach, we orient undirected edges away from s
                        if (edge_u_reg[i] == current_node) begin
                            // Orient away from current_node (u->v)
                            min_orient_reg[i] <= 1'b1;
                            if (!visited_min[edge_v_reg[i]]) begin
                                visited_min[edge_v_reg[i]] <= 1'b1;
                                queue[queue_tail] <= edge_v_reg[i];
                                queue_tail <= queue_tail + 4'd1;
                                min_reach <= min_reach + 5'd1;
                            end
                        end else if (edge_v_reg[i] == current_node) begin
                            // Orient away from current_node (v->u)
                            min_orient_reg[i] <= 1'b0;
                            if (!visited_min[edge_u_reg[i]]) begin
                                visited_min[edge_u_reg[i]] <= 1'b1;
                                queue[queue_tail] <= edge_u_reg[i];
                                queue_tail <= queue_tail + 4'd1;
                                min_reach <= min_reach + 5'd1;
                            end
                        end
                    end
                end
            end
            cycle_count <= cycle_count + 4'd1;
        end
    end

    // Output results
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            max_orient <= max_orient_reg;
            min_orient <= min_orient_reg;
            done <= 1'b1;
        end else if (state == DONE_STATE) begin
            done <= 1'b0;
        end
    end

    // Reset queue for next pass
    always @(posedge clk) begin
        if (state == MAX_BFS && queue_head == queue_tail) begin
            // Reset queue for min BFS
            queue_head <= 4'd0;
            queue_tail <= 4'd1;
            visited_min <= 16'd0;
            visited_min[s_reg] <= 1'b1;
            queue[0] <= s_reg;
            min_reach <= 5'd1;
            cycle_count <= 4'd0;
        end
    end

endmodule