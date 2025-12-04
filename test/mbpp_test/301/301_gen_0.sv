module dict_depth_calculator (
    input               clk,
    input               rst_n,
    input               start,
    input       [3:0]   max_nodes,
    input       [63:0]  node_data,
    output reg  [3:0]   depth_result,
    output reg          done
);

    // State encoding
    localparam IDLE  = 2'b00;
    localparam INIT  = 2'b01;
    localparam BFS   = 2'b10;
    localparam DONE  = 2'b11;

    reg [1:0] state, next_state;

    // BFS frontier bitmasks (max 8 nodes)
    reg [7:0] frontier;       // current layer nodes
    reg [7:0] next_frontier;  // next layer nodes

    // depth counter
    reg [3:0] depth;

    // control flags
    reg bfs_active;

    // Pre-decode node_data into parent and child_count arrays
    // node_data layout (per node i, 0..7):
    // [ (8*i+7):(8*i+4) ] = parent_index
    // [ (8*i+3):(8*i+0) ] = child_count (not directly needed for BFS depth)

    function [3:0] get_parent;
        input [63:0] data;
        input [2:0]  idx;
        reg   [5:0]  base;
    begin
        base = idx * 8;
        get_parent = data[base+7 -: 4];
    end
    endfunction

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
            end
            INIT: begin
                next_state = BFS;
            end
            BFS: begin
                if (!bfs_active)
                    next_state = DONE;
            end
            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    reg [7:0] frontier_next_reg;
    reg       bfs_active_next;
    reg [3:0] depth_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            frontier     <= 8'b0;
            next_frontier<= 8'b0;
            depth        <= 4'd0;
            depth_result <= 4'd0;
            done         <= 1'b0;
            bfs_active   <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done         <= 1'b0;
                    depth_result <= 4'd0;
                    depth        <= 4'd0;
                    frontier     <= 8'b0;
                    next_frontier<= 8'b0;
                    bfs_active   <= 1'b0;
                    if (start) begin
                        // prepare in INIT on next cycle
                    end
                end

                INIT: begin
                    // Initialize BFS starting from root node 0
                    // Ensure max_nodes >= 1 implicitly; if 0, frontier will be zero
                    if (max_nodes != 0)
                        frontier <= 8'b0000_0001;  // node 0 as root
                    else
                        frontier <= 8'b0000_0000;

                    next_frontier <= 8'b0000_0000;
                    depth         <= 4'd0;
                    bfs_active    <= (max_nodes != 0);
                    done          <= 1'b0;
                end

                BFS: begin
                    // Compute next_frontier combinationally (unrolled loops)
                    frontier_next_reg = 8'b0000_0000;

                    if (bfs_active) begin
                        // For each possible node j (0..7) that exists
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < max_nodes) begin
                                // If node j has a parent in current frontier, include it in next frontier
                                if (frontier[get_parent(node_data, i)]) begin
                                    frontier_next_reg[i] = 1'b1;
                                end
                            end
                        end

                        // Remove the root (node 0) from being its own child
                        frontier_next_reg[0] = 1'b0;

                        // Update depth and activity
                        if (frontier_next_reg != 8'b0000_0000 && depth < 4'd8) begin
                            depth_next       = depth + 4'd1;
                            bfs_active_next  = 1'b1;
                        end else begin
                            // No more nodes or depth limit reached
                            depth_next       = depth;
                            bfs_active_next  = 1'b0;
                        end
                    end else begin
                        frontier_next_reg = 8'b0000_0000;
                        depth_next        = depth;
                        bfs_active_next   = 1'b0;
                    end

                    // Apply updates
                    frontier     <= frontier_next_reg;
                    next_frontier<= 8'b0000_0000; // not used separately in this implementation
                    depth        <= depth_next;
                    bfs_active   <= bfs_active_next;

                    // No done flag here; set in DONE state
                    done         <= 1'b0;
                end

                DONE: begin
                    // Saturate depth to 8 on output
                    depth_result <= (depth > 4'd8) ? 4'd8 : depth;
                    done         <= 1'b1;
                    // Hold values until start is deasserted and we transition back to IDLE
                end

                default: begin
                    state        <= IDLE;
                    frontier     <= 8'b0;
                    next_frontier<= 8'b0;
                    depth        <= 4'd0;
                    depth_result <= 4'd0;
                    done         <= 1'b0;
                    bfs_active   <= 1'b0;
                end
            endcase
        end
    end

endmodule