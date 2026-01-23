module bipartite_battle (
    input clk,
    input rst_n,
    input start,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MAX_VERTICES = 3;
    parameter MAX_EDGES = MAX_VERTICES * MAX_VERTICES;
    parameter MODULO = 32'd1000000007;
    parameter TOTAL_GRAPHS = 512; // 2^9
    parameter GRUNDY_MEM_SIZE = 512; // 2^9
    parameter GRUNDY_MEM_ADDR_W = 9;

    // State Encoding for Main FSM
    localparam S_IDLE = 4'b0001;
    localparam S_PREP = 4'b0010;
    localparam S_CALC_G = 4'b0100;
    localparam S_UPDATE = 4'b1000;

    // State Encoding for Sub FSM (Grundy Calc)
    localparam G_IDLE = 4'b0001;
    localparam G_CHECK_MEM = 4'b0010;
    localparam G_CALC_MEX = 4'b0100;
    localparam G_FINISH = 4'b1000;

    // Main FSM Regs
    reg [3:0] m_state, m_next;
    reg [8:0] graph_idx; // 0 to 511
    reg [31:0] result_reg;
    reg done_reg;

    // Sub FSM Regs
    reg [3:0] g_state, g_next;
    reg [8:0] current_graph; // The graph configuration currently being calculated
    reg [8:0] sub_addr; // Iterator for neighbors
    reg [2:0] mex_calc [0:7]; // Array to track reachable Grundy numbers
    reg [3:0] mex_val; // Computed mex
    reg [8:0] neighbor_graph; // Temp storage for neighbor graph

    // Memory for Grundy Numbers (Dual Port for efficiency)
    reg [3:0] grundy_mem [0:GRUNDY_MEM_SIZE-1];
    reg grundy_mem_wren;
    reg [GRUNDY_MEM_ADDR_W-1:0] grundy_mem_addr_r;
    reg [GRUNDY_MEM_ADDR_W-1:0] grundy_mem_addr_w;
    reg [3:0] grundy_mem_data_in;
    wire [3:0] grundy_mem_data_out;

    // Initialize Memory (Combinational Read Logic)
    assign grundy_mem_data_out = grundy_mem[grundy_mem_addr_r];

    // Integer for loops
    integer i;

    // ============================================
    // Main FSM: Iterate through all graphs
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_state <= S_IDLE;
            result_reg <= 0;
            done_reg <= 0;
            graph_idx <= 0;
        end else begin
            m_state <= m_next;

            case (m_state)
                S_IDLE: begin
                    if (start) begin
                        result_reg <= 0;
                        done_reg <= 0;
                        graph_idx <= 0;
                    end
                end

                S_PREP: begin
                    // Ready to start iteration
                    graph_idx <= 0;
                    result_reg <= 0;
                end

                S_CALC_G: begin
                    // Handled by Sub FSM logic below
                end

                S_UPDATE: begin
                    // Check if current graph has Grundy 0 (Losing state)
                    // Note: For N=1, the game is losing if the single graph has Grundy 0.
                    // If we were doing N=2, we would XOR two grundy numbers.
                    // Here we count single graphs that are losing (Grundy 0).
                    if (grundy_mem_data_out == 4'd0) begin
                        result_reg <= (result_reg + 1) % MODULO;
                    end

                    if (graph_idx == TOTAL_GRAPHS - 1) begin
                        // Last graph processed
                    end else begin
                        graph_idx <= graph_idx + 1;
                    end
                end

                S_DONE: begin
                    done_reg <= 1;
                end
            endcase
        end
    end

    // Main FSM Combinational Logic
    always @(*) begin
        case (m_state)
            S_IDLE: m_next = start ? S_PREP : S_IDLE;
            S_PREP: m_next = S_CALC_G;
            S_CALC_G: begin
                // Wait for Sub-FSM to finish
                if (g_state == G_IDLE) // Sub FSM returns to idle when done with specific task? No, better to flag it.
                    // Let's use a specific signal or check internal state of Sub FSM
                    // We will transition to UPDATE when Sub FSM is done with current_graph
                    // Actually, let's make Sub FSM run once per Main FSM request.
                    m_next = (g_state == G_IDLE && g_prev_done) ? S_UPDATE : S_CALC_G;
                else
                    m_next = S_CALC_G;
            end
            S_UPDATE: begin
                if (graph_idx == TOTAL_GRAPHS - 1)
                    m_next = S_DONE;
                else
                    m_next = S_CALC_G; // Next graph
            end
            S_DONE: m_next = S_DONE;
            default: m_next = S_IDLE;
        endcase
    end

    // ============================================
    // Sub FSM: Compute Grundy Number
    // ============================================
    // Signal to track if Sub FSM finished a calculation cycle
    reg g_prev_done;
    reg g_task_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            g_state <= G_IDLE;
            g_prev_done <= 1; // Ready for next task initially
        end else begin
            g_state <= g_next;

            // Capture task completion for Main FSM handshake
            if (g_next == G_IDLE) g_prev_done <= 1;
            else if (g_state == G_IDLE && g_next == G_CHECK_MEM) g_prev_done <= 0;

            case (g_state)
                G_IDLE: begin
                    // Waiting for Main FSM to set current_graph
                    if (m_state == S_PREP || (m_state == S_UPDATE && graph_idx < TOTAL_GRAPHS)) begin
                        // Load new graph target from Main FSM context
                        // We need to transfer graph_idx to current_graph when transitioning to CALC_G
                        // This logic is tricky without a specific trigger.
                        // We will handle loading in G_CHECK_MEM if g_state was IDLE.
                    end
                end

                G_CHECK_MEM: begin
                    // Read memory to see if we already know Grundy for current_graph
                    // Address is current_graph
                end

                G_CALC_MEX: begin
                    // Logic to generate neighbors and update mex
                    // Iterates sub_addr 0 to 8
                    // Reads grundy_mem for neighbor, sets mex_calc
                end

                G_FINISH: begin
                    // Write result to memory, reset state
                    grundy_mem_wren <= 1;
                    grundy_mem_addr_w <= current_graph;
                    grundy_mem_data_in <= mex_val;
                end
            endcase

            // Reset write enable after cycle
            if (g_state != G_FINISH) grundy_mem_wren <= 0;
        end
    end

    // Sub FSM Combinational Logic
    reg [8:0] temp_neighbor;
    always @(*) begin
        // Default assignments
        grundy_mem_addr_r = 0;
        grundy_mem_addr_w = 0;
        grundy_mem_data_in = 0;

        case (g_state)
            G_IDLE: begin
                if (m_state == S_CALC_G && g_prev_done) begin
                    // Main FSM wants us to calculate a new graph
                    // Trigger transition to CHECK_MEM
                    g_next = G_CHECK_MEM;
                end else begin
                    g_next = G_IDLE;
                end
            end

            G_CHECK_MEM: begin
                // Check memory for current_graph
                grundy_mem_addr_r = current_graph;

                // Small delay handling: Since memory is combinational, we check result next cycle or assume we need a cycle.
                // Let's check stored value from previous cycle (if any) or use combinational lookup immediately.
                // Since the memory is combinational read, `grundy_mem_data_out` is valid immediately.
                // However, to be robust with synthesis and FSM state, we usually wait or latch.
                // Let's check the value read. If it's valid (we init memory properly), we can finish.
                // NOTE: We must initialize memory! We can do that in IDLE or assume it's garbage and force calculation.
                // For this algorithm, we assume memory is initially 0 (indicating uncalculated if we use a separate bit, or assuming 0 is valid).
                // To fix ambiguity, let's use a valid bit array? 
                // With 512 entries, we can just assume we calculate everything.
                // Wait, we can't skip calculation without knowing if it's calculated.
                // Let's assume we calculate everything.
                // Optimization: If we find a stored value (non-zero might be ambiguous, 0 is valid), we can't distinguish.
                // Let's just trigger calculation. We don't have enough regs for a visited bit array easily.
                // So, let's go to G_CALC_MEX always for this exercise (unoptimized).
                // Or better: We rely on the fact that we solve in topological order? No, it's a cycle.
                // Okay, let's assume we need to calculate.
                g_next = G_CALC_MEX;
            end

            G_CALC_MEX: begin
                // Iterate 0 to 8
                // We need a loop. In HW, we use counter (sub_addr).
                // If sub_addr < 9, stay here.
                // If sub_addr == 9, go to G_FINISH.
                // To implement, we need to update sub_addr in the sequential logic.
                g_next = (sub_addr < 9) ? G_CALC_MEX : G_FINISH;
            end

            G_FINISH: begin
                g_next = G_IDLE;
            end

            default: g_next = G_IDLE;
        endcase
    end

    // Neighbor Generation & Mex Calculation Logic
    // This runs during G_CALC_MEX state
    // We need to latch the neighbor graph and its grundy value.
    reg [3:0] neighbor_grundy;
    reg [8:0] local_current_graph;

    always @(posedge clk) begin
        if (g_state == G_IDLE && m_state == S_CALC_G && g_prev_done) begin
            // Load new task
            local_current_graph <= graph_idx;
            current_graph <= graph_idx;
            sub_addr <= 0;
            // Reset mex_calc array
            for (i = 0; i < 8; i = i + 1) mex_calc[i] <= 0;
        end else if (g_state == G_CALC_MEX) begin
            // Process current sub_addr
            // 1. Generate Neighbor Graph based on local_current_graph and sub_addr (edge index)
            // sub_addr 0..8 corresponds to [row/col].
            // Game Move: Remove edge (if exists) or Remove Vertex (Row or Col).
            // Let's implement: Remove Edge at (sub_addr/3, sub_addr%3).
            // And Remove Row sub_addr/3. And Remove Col sub_addr%3.
            // Wait, we need to iterate ALL possible moves.
            // Moves: 
            // - Delete edge at (i, j). Only if bit is 1.
            // - Delete vertex i (row i). Removes all edges in row i.
            // - Delete vertex j (col j). Removes all edges in col j.
            // To cover this in 9 steps, we can map sub_addr:
            // 0-8: Try removing edge at that pos (if bit set).
            // 9-11: Try removing Row 0,1,2.
            // 12-14: Try removing Col 0,1,2.
            // Total 15 moves. But we only have 9 slots in sub_addr if we map linearly.
            // Let's extend sub_addr to 0..14.
            // Let's simplify: We iterate all 9 edges. For each, we have 3 moves: remove edge, remove row, remove col.
            // To avoid explosion, let's stick to the problem description: delete vertices or edges.
            // We can use sub_addr 0..14 as suggested.

            // Logic for sub_addr 0..8 (Edge Removal)
            if (sub_addr < 9) begin
                // Check if edge exists
                if (local_current_graph[sub_addr]) begin
                    // Create neighbor graph by clearing this bit
                    neighbor_graph = local_current_graph;
                    neighbor_graph[sub_addr] = 0;
                    // Request Grundy of neighbor
                    grundy_mem_addr_r = neighbor_graph;
                    // Latch result next cycle? 
                    // We are in combinational block, so grundy_mem_data_out is valid now.
                    // But we need to store it.
                    // Let's capture neighbor_grundy in seq logic.
                end
            end
            // Logic for sub_addr 9..11 (Remove Row)
            else if (sub_addr < 12) begin
                integer r;
                r = sub_addr - 9;
                neighbor_graph = local_current_graph;
                // Clear bits for row r: indices r*3, r*3+1, r*3+2
                neighbor_graph[r*3] = 0;
                neighbor_graph[r*3+1] = 0;
                neighbor_graph[r*3+2] = 0;
                grundy_mem_addr_r = neighbor_graph;
            end
            // Logic for sub_addr 12..14 (Remove Col)
            else if (sub_addr < 15) begin
                integer c;
                c = sub_addr - 12;
                neighbor_graph = local_current_graph;
                // Clear bits for col c: indices c, c+3, c+6
                neighbor_graph[c] = 0;
                neighbor_graph[c+3] = 0;
                neighbor_graph[c+6] = 0;
                grundy_mem_addr_r = neighbor_graph;
            end
            else begin
                // Done
            end

            // In seq logic, we capture neighbor_grundy to update mex_calc
            // mex_calc is an array of flags 0..7
        end

        if (g_state == G_CALC_MEX && sub_addr < 15) begin
            // Capture the grundy value read in previous cycle (or current combinational read if we add a delay)
            // To be safe, let's assume we read and mark.
            // Since memory is combinational, reading address X gives value immediately.
            // However, we need to latch it.
            // We will latch `neighbor_grundy` in the state machine transition or within G_CALC_MEX.
            // Let's do it here:
            neighbor_grundy <= grundy_mem_data_out;

            // We need to update mex_calc based on the value we just read (from previous sub_addr iteration)
            // Wait, we need to handle the case where sub_addr 0 is processed.
            // On entering sub_addr 0, we calculate address, read memory, and in the NEXT cycle (sub_addr 1), we record the result of sub_addr 0.
            // But we have only 1 cycle per sub_addr.
            // So we must check if the value is valid immediately.
            // Let's check `grundy_mem_data_out` inside the combinational block and set a 'mark' signal.
            // Then in seq block, if 'mark' is high, set the bit.
        end
    end

    // Refined Sub-FSM Logic for State G_CALC_MEX
    // We need to handle the loop of 15 iterations carefully.
    // We will expand `sub_addr` range to 0..14.
    // We need to calculate the neighbor Grundy value in the same cycle to update the tracking array.

    reg [3:0] step_mex_calc [0:7]; // Array for mex calculation within G_CALC_MEX state
    reg step_valid;

    // Separate block for calculation to avoid timing loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sub_addr <= 0;
            for (i = 0; i < 8; i = i + 1) step_mex_calc[i] <= 0;
        end else if (g_state == G_IDLE && g_next == G_CHECK_MEM) begin
            sub_addr <= 0;
            for (i = 0; i < 8; i = i + 1) step_mex_calc[i] <= 0;
        end else if (g_state == G_CALC_MEX) begin
            // We are processing sub_addr.
            // We have calculated `grundy_mem_addr_r` combinational based on sub_addr.
            // Now we read `grundy_mem_data_out`.
            // We mark the mex bit.

            if (sub_addr < 15) begin
                // Mark the mex bit if the graph move is valid and grundy is < 8
                // Note: Some moves might result in the same graph (e.g. removing non-existent edge). 
                // We should only consider valid moves.
                // We need to check if the generated neighbor graph is different from current?
                // Or simply if the edge existed (for edge moves).
                // For vertex moves, it's always a move (unless graph is empty).

                // Logic to determine if current step is valid and what grundy it produces:
                // This logic is computed in the combinational block triggering this state.
                // We need to know `step_valid` and `step_grundy`.

                // Let's compute step validity in combinational logic based on local_current_graph and sub_addr.
                // And pass it into this block.
                // Due to Verilog scope, let's define a combinational helper block below.

                if (step_valid && step_grundy < 8) begin
                    step_mex_calc[step_grundy] <= 1;
                end

                sub_addr <= sub_addr + 1;
            end
        end else if (g_state == G_FINISH) begin
            sub_addr <= 0; // Reset for next time
        end
    end

    // Combinational Logic to determine Step Validity and Step Grundy
    // This runs continuously, but is only "used" by the seq logic above.
    reg [8:0] step_neighbor_graph;
    reg [3:0] step_grundy_val;
    reg step_is_valid;

    always @(*) begin
        // Default
        step_neighbor_graph = local_current_graph;
        step_is_valid = 0;

        // Calculate neighbor address and validity
        if (sub_addr < 9) begin
            // Edge move
            if (local_current_graph[sub_addr]) begin
                step_neighbor_graph[sub_addr] = 0;
                step_is_valid = 1;
            end
        end else if (sub_addr < 12) begin
            // Row move
            integer r = sub_addr - 9;
            // Check if row has any edges to make it a meaningful move
            if (local_current_graph[r*3] || local_current_graph[r*3+1] || local_current_graph[r*3+2]) begin
                step_neighbor_graph[r*3] = 0;
                step_neighbor_graph[r*3+1] = 0;
                step_neighbor_graph[r*3+2] = 0;
                step_is_valid = 1;
            end
        end else if (sub_addr < 15) begin
            // Col move
            integer c = sub_addr - 12;
            if (local_current_graph[c] || local_current_graph[c+3] || local_current_graph[c+6]) begin
                step_neighbor_graph[c] = 0;
                step_neighbor_graph[c+3] = 0;
                step_neighbor_graph[c+6] = 0;
                step_is_valid = 1;
            end
        end

        // We need the Grundy value of this neighbor.
        // This requires reading the memory.
        // IMPORTANT: We can't read the memory we are currently calculating if there is a cycle.
        // However, this is a recursive calculation.
        // To resolve this in hardware without stack, we rely on the fact that we iterate all 512 graphs in Main FSM.
        // But Main FSM iterates linearly 0..511. 
        // A move always decreases the number of edges or vertices, which generally decreases the graph integer value? 
        // Not necessarily (e.g. removing a vertex changes bits).
        // However, we are iterating 0..511. If we can ensure that neighbor graphs are always "smaller" than current, we can process in order.
        // But iterating 0..511 does not guarantee that neighbor is processed.
        // Solution: We use the iterative nature.
        // Actually, for a single graph calculation, we need a way to handle the recursion.
        // Given the small state space (512) and Main FSM iterating, we can use dynamic programming with a queue or simply rely on the fact that we calculate all.
        // Let's change the Main Loop: Iterate 0..511. For each, calculate Grundy.
        // Since we iterate 0..511, we can't guarantee neighbors (which might be higher numbers) are done.
        // So we need a different approach: 
        // We can iterate 0..511 multiple times until convergence? No.
        // We must solve the game graph.
        // Alternative: 
        // The Main FSM calls the Sub FSM.
        // If Sub FSM needs a neighbor's Grundy that isn't calculated yet, it can't just read garbage.
        // But we are iterating 0..511. Most neighbors will be smaller? No.
        // Wait, if we iterate 0..511, and we find a neighbor that hasn't been calculated, we are stuck.
        // SOLUTION: We don't need to solve recursively inside one cycle.
        // We need a 'Solver Engine' that iterates through ALL states multiple times until stable, or processes them in topological order.
        // Topological order: Order by number of edges (asc) then by value.
        // Edges: popcount of the 9-bit number.
        // We can iterate popcount from 0 to 9.
        // Let's modify Main FSM: 
        // Iterate popcount (0..9). Iterate all graphs with that popcount.
        // Then neighbors (moves) will have strictly fewer edges, so they are already processed.
        // This solves the dependency issue.

        // REVISED PLAN:
        // 1. Main FSM iterates edge_count (0 to 9).
        // 2. Inner loop iterates all 512 graphs. If popcount == edge_count, process.
        // 3. Sub FSM calculates Grundy using the memory (which is populated for lower edge counts).

        // Helper for popcount:
    end

    // Re-implement Main FSM for Topological Order (Edge Count)
    // We need a helper for popcount. Verilog doesn't have built-in popcount easily in synthesis without 2001.
    // We will implement a simple popcount logic or just iterate 0..511 and filter by popcount.

    reg [3:0] edge_count; // 0 to 9
    reg [8:0] inner_idx;  // 0 to 511

    // Popcount logic
    wire [3:0] popcount;
    popcount_9bit pc_inst (.in(inner_idx), .out(popcount));

    // Update Main State Machine Logic (Revised)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_state <= S_IDLE;
            result_reg <= 0;
            done_reg <= 0;
            edge_count <= 0;
            inner_idx <= 0;
        end else begin
            m_state <= m_next;

            case (m_state)
                S_IDLE: begin
                    if (start) begin
                        result_reg <= 0;
                        done_reg <= 0;
                        edge_count <= 0;
                        inner_idx <= 0;
                        // Clear memory (optional, or assume garbage) -> Better to clear.
                        // We can clear memory in a separate state or assume we overwrite.
                    end
                end

                S_PREP: begin
                    edge_count <= 0;
                    inner_idx <= 0;
                    // Init memory writes to zero? No, we'll just calculate.
                end

                S_CALC_G: begin
                    // Wait for Sub FSM
                end

                S_UPDATE: begin
                    // Count if losing (Grundy 0)
                    // We are processing 'current_graph' which is 'inner_idx'
                    // Result should be updated here.
                    if (grundy_mem_data_out == 4'd0) begin
                        result_reg <= (result_reg + 1) % MODULO;
                    end

                    // Advance counters
                    if (inner_idx == 511) begin
                        inner_idx <= 0;
                        if (edge_count == 9) begin
                            // Done with all
                        end else begin
                            edge_count <= edge_count + 1;
                        end
                    end else begin
                        inner_idx <= inner_idx + 1;
                    end
                end

                S_DONE: begin
                    done_reg <= 1;
                end
            endcase
        end
    end

    // Main FSM Next State Logic (Revised)
    wire pop_match = (popcount == edge_count);

    always @(*) begin
        case (m_state)
            S_IDLE: m_next = start ? S_PREP : S_IDLE;
            S_PREP: m_next = S_CALC_G;
            S_CALC_G: begin
                // If popcount matches, we need to calculate
                if (pop_match) begin
                    // Check if Sub FSM is done
                    if (g_state == G_IDLE && g_prev_done) 
                        m_next = S_UPDATE;
                    else 
                        m_next = S_CALC_G;
                end else begin
                    // Skip this graph
                    m_next = S_UPDATE;
                end
            end
            S_UPDATE: begin
                // Check if we finished all
                if (edge_count == 9 && inner_idx == 511) begin
                    m_next = S_DONE;
                end else begin
                    m_next = S_CALC_G;
                end
            end
            S_DONE: m_next = S_DONE;
            default: m_next = S_IDLE;
        endcase
    end

    // Sub FSM Trigger Update
    // When entering S_CALC_G with g_prev_done, we need to set current_graph = inner_idx
    // This is tricky with `always @(*)`. 
    // Let's use a control signal.
    reg start_sub_calc;
    always @(posedge clk) begin
        start_sub_calc <= 0;
        if (m_state == S_CALC_G && m_next == S_CALC_G && g_state == G_IDLE && g_prev_done && pop_match) begin
            start_sub_calc <= 1;
        end
    end

    // Update Sub FSM (G_IDLE transition)
    // Modify G_IDLE case in Sub FSM
    always @(*) begin
        case (g_state)
            G_IDLE: begin
                if (start_sub_calc) begin
                    g_next = G_CHECK_MEM;
                end else begin
                    g_next = G_IDLE;
                end
            end
            // ... (Rest remains same, but we need to handle the 15 steps loop)
            G_CHECK_MEM: begin
                // Since we are iterating in topological order, we can assume memory is valid.
                // But we need to calculate it now.
                g_next = G_CALC_MEX;
            end
            G_CALC_MEX: begin
                if (sub_addr < 15) g_next = G_CALC_MEX;
                else g_next = G_FINISH;
            end
            G_FINISH: g_next = G_IDLE;
            default: g_next = G_IDLE;
        endcase
    end

    // Adjusted Sub FSM Sequential Logic
    // We need to use `current_graph` effectively. 
    // `current_graph` is set in G_IDLE or just used from `inner_idx`?
    // To be clean, let's latch `inner_idx` into `current_graph` when `start_sub_calc` is high.
    always @(posedge clk) begin
        if (start_sub_calc) begin
            current_graph <= inner_idx;
            local_current_graph <= inner_idx;
            sub_addr <= 0;
            // Reset tracking array
            for (i = 0; i < 8; i = i + 1) step_mex_calc[i] <= 0;
        end else if (g_state == G_CALC_MEX) begin
            // Process step
            // We have step_is_valid, step_grundy_val from combinational logic
            if (step_is_valid && step_grundy_val < 8) begin
                step_mex_calc[step_grundy_val] <= 1;
            end
            if (sub_addr < 15) begin
                sub_addr <= sub_addr + 1;
            end
        end else if (g_state == G_FINISH) begin
            // Write to memory
            grundy_mem_wren <= 1;
            grundy_mem_addr_w <= current_graph;
            // Calculate Mex
            mex_val <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                if (step_mex_calc[i] == 0) mex_val <= i;
            end
            grundy_mem_data_in <= mex_val; // This assignment might be late if mex_val is sequential.
            // Better to calculate mex combinationally in G_FINISH.
        end else begin
            grundy_mem_wren <= 0;
        end
    end

    // Combinational Mex calculation for G_FINISH
    reg [3:0] next_mex;
    always @(*) begin
        next_mex = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (step_mex_calc[i] == 0) next_mex = i;
        end
    end

    always @(posedge clk) begin
        if (g_state == G_FINISH) begin
            grundy_mem_data_in <= next_mex;
        end
    end

    // Updated Combinational Logic for Step Calculation
    // This needs to look at `sub_addr` and `local_current_graph`.
    // `local_current_graph` is updated at start of calculation.
    // We need to compute the neighbor's Grundy number immediately.
    // The neighbor's address is `step_neighbor_graph`.
    // We set `grundy_mem_addr_r` to this neighbor.
    // We read `grundy_mem_data_out`.
    // This read is valid in the same cycle (combinational read memory).

    always @(*) begin
        // Determine neighbor graph and validity
        step_neighbor_graph = local_current_graph;
        step_is_valid = 0;

        if (sub_addr < 9) begin
            if (local_current_graph[sub_addr]) begin
                step_neighbor_graph[sub_addr] = 0;
                step_is_valid = 1;
            end
        end else if (sub_addr < 12) begin
            integer r = sub_addr - 9;
            if (local_current_graph[r*3] || local_current_graph[r*3+1] || local_current_graph[r*3+2]) begin
                step_neighbor_graph[r*3] = 0;
                step_neighbor_graph[r*3+1] = 0;
                step_neighbor_graph[r*3+2] = 0;
                step_is_valid = 1;
            end
        end else if (sub_addr < 15) begin
            integer c = sub_addr - 12;
            if (local_current_graph[c] || local_current_graph[c+3] || local_current_graph[c+6]) begin
                step_neighbor_graph[c] = 0;
                step_neighbor_graph[c+3] = 0;
                step_neighbor_graph[c+6] = 0;
                step_is_valid = 1;
            end
        end

        // Now we need the Grundy of this neighbor.
        // Since we are in state G_CALC_MEX, `step_neighbor_graph` is the address.
        // We must read from memory.
        // However, we are already using `grundy_mem_addr_r` for reading.
        // We should assign `grundy_mem_addr_r` to `step_neighbor_graph`.
        // But `step_neighbor_graph` depends on `sub_addr`.
        grundy_mem_addr_r = step_neighbor_graph;

        // The value read is `grundy_mem_data_out`.
        // We need to map this to `step_grundy_val`.
        step_grundy_val = grundy_mem_data_out;
    end

    // The `step_grundy_val` is used in the sequential block to update `step_mex_calc`.
    // This creates a path: Combinational -> Sequential -> Combinational loop.
    // To break it: 
    // The `step_mex_calc` update in `G_CALC_MEX` state uses `step_grundy_val`.
    // But `step_grundy_val` depends on `grundy_mem_addr_r` which is combinational.
    // If we use the standard synchronous update logic:
    // `if (step_valid) step_mex_calc[step_grundy] <= 1;`
    // This samples `step_grundy` at the clock edge (or slightly before).
    // However, `step_grundy` is changing as `sub_addr` changes.
    // We are iterating `sub_addr` from 0 to 14.
    // We have one cycle for each `sub_addr`.
    // So for sub_addr=0, we set address, read memory, and mark `step_mex_calc`.
    // This works fine.

    // Final check on Result Update:
    // In S_UPDATE, we read `grundy_mem_data_out`. 
    // `grundy_mem_addr_r` is currently driven by `step_neighbor_graph` in G_CALC_MEX.
    // When S_UPDATE is active, G_CALC_MEX is NOT active (transition to S_UPDATE happens after G_IDLE).
    // Wait. S_UPDATE comes after G_FINISH -> G_IDLE.
    // In S_UPDATE, we need to read the grundy of the current graph.
    // We should set `grundy_mem_addr_r = inner_idx` in S_UPDATE.
    // Currently `grundy_mem_addr_r` is combinational logic driven by step_neighbor_graph.
    // We need to multiplex `grundy_mem_addr_r`.

    // Modified Combinational Logic for Memory Read Address:
    always @(*) begin
        if (m_state == S_UPDATE) begin
            grundy_mem_addr_r = inner_idx;
        end else if (g_state == G_CALC_MEX) begin
            grundy_mem_addr_r = step_neighbor_graph;
        end else if (g_state == G_CHECK_MEM || g_state == G_IDLE) begin
            // Not reading effectively or defaults
            grundy_mem_addr_r = 0;
        end else begin
            grundy_mem_addr_r = 0;
        end
    end

    // Cleanup: 
    // 1. `grundy_mem_data_in` assignment in G_FINISH.
    // We need to ensure `next_mex` is available.
    // The sequential block assigns `grundy_mem_data_in <= next_mex`.
    // `next_mex` is combinational on `step_mex_calc`.
    // This is fine.

    // 2. Result Update in S_UPDATE.
    // We check if `grundy_mem_data_out == 0`.
    // `grundy_mem_addr_r` is `inner_idx`. Correct.

    // 3. `local_current_graph` initialization.
    // Needs to be set when `start_sub_calc` is true.
    // Yes, handled.

    // 4. Edge case: Empty graph (0 edges).
    // Popcount 0. Moves are impossible (no edges to remove, removing vertices results in empty graph which is 0).
    // So `step_mex_calc` stays all 0. `next_mex` becomes 0. Grundy 0. Correct.

endmodule

// Helper module for popcount
module popcount_9bit (
    input [8:0] in,
    output reg [3:0] out
);
    always @(*) begin
        out = 0;
        if (in[0]) out = out + 1;
        if (in[1]) out = out + 1;
        if (in[2]) out = out + 1;
        if (in[3]) out = out + 1;
        if (in[4]) out = out + 1;
        if (in[5]) out = out + 1;
        if (in[6]) out = out + 1;
        if (in[7]) out = out + 1;
        if (in[8]) out = out + 1;
    end
endmodule