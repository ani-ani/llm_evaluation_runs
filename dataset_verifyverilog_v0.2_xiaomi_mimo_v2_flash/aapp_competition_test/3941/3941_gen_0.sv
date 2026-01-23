module door_unlock_solver(
    input clk,
    input rst_n,
    input start,
    input [1:0] room_count,
    input [1:0] switch_count,
    input [3:0] room_status,
    input [3:0] switch_room_map_0,
    input [3:0] switch_room_map_1,
    input [3:0] switch_room_map_2,
    input [3:0] switch_room_map_3,
    output reg result,
    output reg done
);

    // FSM States
    parameter S_IDLE = 4'd0;
    parameter S_BUILD = 4'd1;
    parameter S_KOSA1_INIT = 4'd2;
    parameter S_KOSA1_LOOP = 4'd3;
    parameter S_KOSA1_DFS = 4'd4;
    parameter S_TRANSPOSE = 4'd5;
    parameter S_KOSA2_INIT = 4'd6;
    parameter S_KOSA2_LOOP = 4'd7;
    parameter S_KOSA2_DFS = 4'd8;
    parameter S_CHECK = 4'd9;
    parameter S_DONE = 4'd10;

    reg [3:0] state;

    // Registers for input latching
    reg [1:0] l_room_cnt;
    reg [3:0] l_status;
    reg [3:0] l_map [0:3];

    // Graph representation (Adjacency Matrix)
    reg [7:0] adj [0:7];    // 8 nodes, 8-bit rows
    reg [7:0] adj_t [0:7];  // Transpose

    // SCC Data
    reg [7:0] scc [0:7];    // SCC ID for each node
    reg [2:0] scc_id_cnt;   // Current SCC ID to assign

    // Iteration Counters
    reg [2:0] room_idx;     // Room index for BUILD state
    reg [2:0] i, j;         // General purpose indices
    reg [2:0] u;            // Current node in DFS

    // Stacks and Stack Pointers
    reg [2:0] stack [0:7];  // Main DFS stack (nodes)
    reg [2:0] sp;           // Stack pointer

    reg [2:0] stack_child [0:7]; // Stores child pointer for each stack level

    // Finish Stack for Pass 1
    reg [2:0] finish_stack [0:7];
    reg [2:0] fsp;

    // Visited markers
    reg [7:0] visited_1;    // Visited in Pass 1
    reg [7:0] visited_2;    // Visited in Pass 2

    // Helper to find switches for a room (Combinational)
    reg [2:0] swA, swB;
    always @(*) begin
        swA = 0; swB = 0;
        // Find first switch (A)
        if (l_map[0][room_idx]) swA = 0;
        else if (l_map[1][room_idx]) swA = 1;
        else if (l_map[2][room_idx]) swA = 2;
        else if (l_map[3][room_idx]) swA = 3;
        // Find second switch (B)
        if (l_map[0][room_idx] && 0 != swA) swB = 0;
        if (l_map[1][room_idx] && 1 != swA) swB = 1;
        if (l_map[2][room_idx] && 2 != swA) swB = 2;
        if (l_map[3][room_idx] && 3 != swA) swB = 3;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        // Latch inputs
                        l_room_cnt <= room_count;
                        l_status <= room_status;
                        l_map[0] <= switch_room_map_0;
                        l_map[1] <= switch_room_map_1;
                        l_map[2] <= switch_room_map_2;
                        l_map[3] <= switch_room_map_3;

                        // Reset Adjacency Matrix
                        for (int k = 0; k < 8; k++) adj[k] <= 8'b0;

                        room_idx <= 0;
                        done <= 0;
                        result <= 0;
                        state <= S_BUILD;
                    end
                end

                S_BUILD: begin
                    // Add edges for current room
                    if (room_idx < l_room_cnt) begin
                        // Edges for Locked (0) or Unlocked (1)
                        // Node mapping: Switch s -> Pos: s, Neg: s+4
                        if (l_status[room_idx] == 0) begin
                            // Locked: A XOR B = 1
                            // Implications: !A -> B, !B -> A, A -> !B, B -> !A
                            adj[swA + 4] <= adj[swA + 4] | (1 << swB);
                            adj[swB + 4] <= adj[swB + 4] | (1 << swA);
                            adj[swA]     <= adj[swA]     | (1 << (swB + 4));
                            adj[swB]     <= adj[swB]     | (1 << (swA + 4));
                        end else begin
                            // Unlocked: A XOR B = 0
                            // Implications: A -> B, B -> A, !A -> !B, !B -> !A
                            adj[swA]     <= adj[swA]     | (1 << swB);
                            adj[swB]     <= adj[swB]     | (1 << swA);
                            adj[swA + 4] <= adj[swA + 4] | (1 << (swB + 4));
                            adj[swB + 4] <= adj[swB + 4] | (1 << (swA + 4));
                        end
                        room_idx <= room_idx + 1;
                    end else begin
                        // Initialize Pass 1 (Kosaraju)
                        visited_1 <= 8'b0;
                        sp <= 0;
                        fsp <= 0;
                        i <= 0;
                        state <= S_KOSA1_INIT;
                    end
                end

                S_KOSA1_INIT: begin
                    // Reset Stack
                    sp <= 0;
                    // Check next node
                    if (i < 8) begin
                        if (!visited_1[i]) begin
                            // Start DFS from node i
                            u <= i;
                            stack[0] <= i;
                            sp <= 1;
                            visited_1[i] <= 1;
                            stack_child[0] <= 0;
                            state <= S_KOSA1_DFS;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        // Pass 1 Complete
                        state <= S_TRANSPOSE;
                    end
                end

                S_KOSA1_DFS: begin
                    // Iterative DFS using stack
                    if (sp > 0) begin
                        // Current node is at stack[sp-1]
                        if (stack_child[sp-1] < 8) begin
                            // Check next child
                            if (adj[stack[sp-1]][stack_child[sp-1]]) begin
                                if (!visited_1[stack_child[sp-1]]) begin
                                    // Visit child
                                    visited_1[stack_child[sp-1]] <= 1;
                                    stack[sp] <= stack_child[sp-1];
                                    stack_child[sp] <= 0;
                                    sp <= sp + 1;
                                end else begin
                                    // Already visited, check next
                                    stack_child[sp-1] <= stack_child[sp-1] + 1;
                                end
                            end else begin
                                // Not a child, check next
                                stack_child[sp-1] <= stack_child[sp-1] + 1;
                            end
                        end else begin
                            // No more children, pop
                            sp <= sp - 1;
                            finish_stack[fsp] <= stack[sp-1];
                            fsp <= fsp + 1;
                            if (sp > 1) begin
                                // Backtrack: Increment parent's child pointer
                                stack_child[sp-2] <= stack_child[sp-2] + 1;
                            end
                        end
                    end else begin
                        // Stack empty, continue outer loop
                        i <= i + 1;
                        state <= S_KOSA1_INIT;
                    end
                end

                S_TRANSPOSE: begin
                    // Compute Transpose: adj_t[j][i] = adj[i][j]
                    // We do this iteratively to save combinational depth
                    if (i < 8) begin
                        // Transpose row i (column of adj)
                        adj_t[i] <= {adj[7][i], adj[6][i], adj[5][i], adj[4][i], adj[3][i], adj[2][i], adj[1][i], adj[0][i]};
                        i <= i + 1;
                    end else begin
                        // Initialize Pass 2
                        visited_2 <= 8'b0;
                        scc_id_cnt <= 0;
                        // Clear SCC assignments
                        for (int k = 0; k < 8; k++) scc[k] <= 8'hFF;
                        i <= 0; // Will iterate fsp
                        state <= S_KOSA2_LOOP;
                    end
                end

                S_KOSA2_LOOP: begin
                    // Iterate through finish_stack in reverse order
                    if (i < fsp) begin
                        u <= finish_stack[fsp - 1 - i];
                        if (visited_2[finish_stack[fsp - 1 - i]]) begin
                            // Already processed, skip
                            i <= i + 1;
                        end else begin
                            // Start DFS on Transpose
                            visited_2[finish_stack[fsp - 1 - i]] <= 1;
                            scc[finish_stack[fsp - 1 - i]] <= scc_id_cnt;
                            stack[0] <= finish_stack[fsp - 1 - i];
                            sp <= 1;
                            stack_child[0] <= 0;
                            state <= S_KOSA2_DFS;
                        end
                    end else begin
                        // Done
                        state <= S_CHECK;
                    end
                end

                S_KOSA2_DFS: begin
                    if (sp > 0) begin
                        if (stack_child[sp-1] < 8) begin
                            // Check child in Transpose graph
                            if (adj_t[stack[sp-1]][stack_child[sp-1]]) begin
                                if (!visited_2[stack_child[sp-1]]) begin
                                    visited_2[stack_child[sp-1]] <= 1;
                                    scc[stack_child[sp-1]] <= scc_id_cnt;
                                    stack[sp] <= stack_child[sp-1];
                                    stack_child[sp] <= 0;
                                    sp <= sp + 1;
                                end else begin
                                    stack_child[sp-1] <= stack_child[sp-1] + 1;
                                end
                            end else begin
                                stack_child[sp-1] <= stack_child[sp-1] + 1;
                            end
                        end else begin
                            // Pop
                            sp <= sp - 1;
                            if (sp == 1) begin
                                // Finished an SCC
                                scc_id_cnt <= scc_id_cnt + 1;
                                state <= S_KOSA2_LOOP;
                            end else begin
                                // Backtrack to parent
                                stack_child[sp-2] <= stack_child[sp-2] + 1;
                            end
                        end
                    end else begin
                        state <= S_KOSA2_LOOP;
                    end
                end

                S_CHECK: begin
                    // Check if variable and negation are in same SCC
                    result <= 1;
                    if (scc[0] == scc[4] || scc[1] == scc[5] || scc[2] == scc[6] || scc[3] == scc[7]) begin
                        result <= 0;
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    done <= 1;
                    if (!start) state <= S_IDLE;
                end
            endcase
        end
    end
endmodule