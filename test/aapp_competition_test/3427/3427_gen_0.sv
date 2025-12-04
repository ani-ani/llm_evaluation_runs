module max_secure_rooms(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_rooms,
    input [3:0] num_doors,
    input [31:0] door_data [0:15],
    output reg [2:0] result,
    output reg done
);

    // FSM States
    typedef enum logic [2:0] {
        S_IDLE          = 3'd0,
        S_INIT          = 3'd1,
        S_NEXT_EDGE     = 3'd2,
        S_BUILD_DFS     = 3'd3,
        S_RUN_DFS       = 3'd4,
        S_EVAL          = 3'd5,
        S_OUTPUT        = 3'd6
    } state_t;

    state_t state, next_state;

    // Internal storage
    // Edge endpoints for internal doors only (exclude external node 15)
    reg [3:0] edge_u [0:15];
    reg [3:0] edge_v [0:15];
    reg [4:0] num_int_edges; // up to 16

    // Iteration over candidate edges
    reg [4:0] cand_idx;        // index over internal edges (0..num_int_edges-1)

    // Working DFS edge index for building adjacency
    reg [4:0] dfs_build_idx;

    // DFS adjacency storage: store up to 16 edges endpoints with a removal filter.
    // We reuse edge_u/edge_v and skip cand_idx when building/using adjacency.

    // DFS arrays
    reg       visited [0:7];      // up to 8 rooms
    reg [3:0] stack_node [0:15];  // DFS stack nodes (depth <= edges)
    reg [4:0] stack_edge_idx [0:15]; // iterator position per stack frame
    reg [4:0] sp;                 // stack pointer

    // Tracking best result
    reg [3:0] best_size;         // up to 8
    reg [3:0] comp_size;         // current component size

    // Temporary signals
    reg [3:0] u_tmp, v_tmp;

    // Extract internal edges from door_data
    integer i;

    // FSM sequential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            result      <= 3'd0;
            done        <= 1'b0;
            num_int_edges <= 5'd0;
            cand_idx    <= 5'd0;
            dfs_build_idx <= 5'd0;
            sp          <= 5'd0;
            best_size   <= 4'd0;
            comp_size   <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                edge_u[i] <= 4'd0;
                edge_v[i] <= 4'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                visited[i] <= 1'b0;
            end
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done      <= 1'b0;
                    result    <= 3'd0;
                    if (start) begin
                        // Build internal edge list from door_data
                        num_int_edges <= 5'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            edge_u[i] <= 4'd0;
                            edge_v[i] <= 4'd0;
                        end
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < num_doors) begin
                                u_tmp = door_data[i][7:4];
                                v_tmp = door_data[i][3:0];
                                // ignore edges connected to external node (4'b1111)
                                if (u_tmp != 4'b1111 && v_tmp != 4'b1111) begin
                                    edge_u[num_int_edges] <= u_tmp;
                                    edge_v[num_int_edges] <= v_tmp;
                                    num_int_edges         <= num_int_edges + 5'd1;
                                end
                            end
                        end
                        best_size   <= 4'd0;
                        cand_idx    <= 5'd0;
                    end
                end

                S_INIT: begin
                    // Initialize for new candidate edge removal
                    // Clear visited
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    sp        <= 5'd0;
                    comp_size <= 4'd0;
                    dfs_build_idx <= 5'd0;
                end

                S_NEXT_EDGE: begin
                    // No sequential ops here beyond those driven by combinational next_state
                end

                S_BUILD_DFS: begin
                    // Push starting node 0 (if within num_rooms)
                    if (num_rooms != 4'd0) begin
                        visited[0]      <= 1'b1;
                        stack_node[0]   <= 4'd0;
                        stack_edge_idx[0] <= 5'd0;
                        sp              <= 5'd1;
                        comp_size       <= 4'd1;
                    end else begin
                        sp        <= 5'd0;
                        comp_size <= 4'd0;
                    end
                end

                S_RUN_DFS: begin
                    if (sp != 5'd0) begin
                        reg [4:0] top;
                        reg [3:0] cur_node;
                        reg [4:0] ei;
                        reg found;
                        top      = sp - 5'd1;
                        cur_node = stack_node[top];
                        ei       = stack_edge_idx[top];
                        found    = 1'b0;

                        // Scan edges until we find unvisited neighbor or exhaust
                        while (ei < num_int_edges && !found) begin
                            if (ei != cand_idx) begin
                                u_tmp = edge_u[ei];
                                v_tmp = edge_v[ei];
                                if (u_tmp < num_rooms && v_tmp < num_rooms) begin
                                    if (u_tmp == cur_node && !visited[v_tmp]) begin
                                        found = 1'b1;
                                        visited[v_tmp] <= 1'b1;
                                        comp_size      <= comp_size + 4'd1;
                                        stack_node[sp] <= v_tmp;
                                        stack_edge_idx[sp] <= 5'd0;
                                        sp <= sp + 5'd1;
                                        stack_edge_idx[top] <= ei + 5'd1;
                                    end else if (v_tmp == cur_node && !visited[u_tmp]) begin
                                        found = 1'b1;
                                        visited[u_tmp] <= 1'b1;
                                        comp_size      <= comp_size + 4'd1;
                                        stack_node[sp] <= u_tmp;
                                        stack_edge_idx[sp] <= 5'd0;
                                        sp <= sp + 5'd1;
                                        stack_edge_idx[top] <= ei + 5'd1;
                                    end else begin
                                        ei = ei + 5'd1;
                                    end
                                end else begin
                                    ei = ei + 5'd1;
                                end
                            end else begin
                                ei = ei + 5'd1;
                            end
                        end

                        if (!found) begin
                            // no more neighbors for this node
                            sp <= sp - 5'd1;
                        end
                    end
                end

                S_EVAL: begin
                    // After DFS complete, comp_size holds size of component reachable from node 0
                    if (comp_size > best_size)
                        best_size <= comp_size;
                end

                S_OUTPUT: begin
                    result <= (best_size[2:0]);
                    done   <= 1'b1;
                end

                default: begin
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_INIT;
            end

            S_INIT: begin
                if (num_int_edges == 5'd0) begin
                    // No internal doors -> no secure component from removing one
                    next_state = S_OUTPUT;
                end else begin
                    next_state = S_BUILD_DFS;
                end
            end

            S_BUILD_DFS: begin
                next_state = S_RUN_DFS;
            end

            S_RUN_DFS: begin
                if (sp == 5'd0) begin
                    next_state = S_EVAL;
                end
            end

            S_EVAL: begin
                if (cand_idx + 5'd1 < num_int_edges) begin
                    next_state = S_INIT;
                end else begin
                    next_state = S_OUTPUT;
                end
            end

            S_OUTPUT: begin
                if (!start)
                    next_state = S_IDLE;
            end

            S_NEXT_EDGE: begin
                // Unused in this implementation
                next_state = S_INIT;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // Candidate index update (sequential dependent on states)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cand_idx <= 5'd0;
        end else begin
            if (state == S_EVAL) begin
                if (cand_idx + 5'd1 < num_int_edges)
                    cand_idx <= cand_idx + 5'd1;
            end else if (state == S_IDLE && start) begin
                cand_idx <= 5'd0;
            end
        end
    end

endmodule