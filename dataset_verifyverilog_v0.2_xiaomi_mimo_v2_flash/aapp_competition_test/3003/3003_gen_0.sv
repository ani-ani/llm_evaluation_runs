module chromatic_number_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] adjacency_matrix [0:7][0:7],
    input [2:0] num_vertices,
    output reg [2:0] chromatic_number,
    output reg done
);

    // State encoding
    localparam IDLE = 5'b00001;
    localparam INIT_COLOR_K = 5'b00010;
    localparam SETUP_BACKTRACK = 5'b00011;
    localparam ASSIGN_COLOR = 5'b00100;
    localparam VERIFY_CONSTRAINT = 5'b00101;
    localparam BACKTRACK = 5'b00110;
    localparam NEXT_VERTEX = 5'b00111;
    localparam FOUND_SOLUTION = 5'b01000;
    localparam INCREMENT_K = 5'b01001;
    localparam DONE = 5'b01010;
    // Check_K is implicit logic or sub-state. We will manage K validity in SETUP or logic.
    // To satisfy state list: CHECK_K -> We use SETUP logic after K is set.
    localparam CHECK_K = 5'b01011; 

    reg [4:0] state, next_state;

    // Registers for backtracking
    reg [2:0] k;              // Current number of colors
    reg [2:0] curr_vertex;    // Current vertex being colored (0 to N-1)
    reg [2:0] colors [0:7];   // Assigned colors for each vertex
    reg [2:0] color_try;      // Color currently trying for curr_vertex
    
    // Helper signals
    reg constraint_violated;
    integer i; // Loop variable
    
    // State Transition & Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            chromatic_number <= 3'b000;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_COLOR_K;
                    end
                end

                INIT_COLOR_K: begin
                    k <= 3'b001; // Start with 1 color
                    state <= CHECK_K;
                end

                CHECK_K: begin
                    // If K > num_vertices, it's impossible (though usually K=1 is enough for any graph)
                    // But strictly, chromatic number <= num_vertices. 
                    // We proceed to SETUP if K <= num_vertices.
                    if (k > num_vertices) begin
                        // Should not happen if logic is correct, but fail safe
                        chromatic_number <= num_vertices; 
                        state <= DONE;
                    end else begin
                        state <= SETUP_BACKTRACK;
                    end
                end

                SETUP_BACKTRACK: begin
                    // Reset vertex pointer and color try
                    curr_vertex <= 3'b000;
                    color_try <= 3'b000;
                    // We assume valid setup. Go to assign.
                    state <= ASSIGN_COLOR;
                end

                ASSIGN_COLOR: begin
                    // Assign current color_try to current vertex
                    // Technically this is just a register update, operation happens logic-wise
                    // We move to verify
                    state <= VERIFY_CONSTRAINT;
                end

                VERIFY_CONSTRAINT: begin
                    // Check if the proposed assignment is valid
                    // We need to check current vertex (curr_vertex) with color_try against all previous vertices
                    // Constraint: if adjacency_matrix[curr_vertex][i] == 1, then colors[i] != color_try
                    // Also check self-loop if any (though usually 0 on diagonal)
                    
                    if (constraint_violated) begin
                        // Try next color
                        if (color_try + 1 < k) begin
                            color_try <= color_try + 1;
                            state <= ASSIGN_COLOR; 
                        end else begin
                            // No more colors to try for this vertex, backtrack
                            if (curr_vertex == 0) begin
                                // Backtracked to root and exhausted colors -> K is invalid
                                state <= INCREMENT_K;
                            end else begin
                                state <= BACKTRACK;
                            end
                        end
                    end else begin
                        // Constraint satisfied
                        colors[curr_vertex] <= color_try; // Commit color
                        
                        if (curr_vertex == num_vertices - 1) begin
                            // All vertices colored
                            state <= FOUND_SOLUTION;
                        end else begin
                            state <= NEXT_VERTEX;
                        end
                    end
                end

                NEXT_VERTEX: begin
                    // Move to next vertex, reset color try to 0
                    curr_vertex <= curr_vertex + 1;
                    color_try <= 3'b000;
                    state <= ASSIGN_COLOR;
                end

                BACKTRACK: begin
                    // Go back one vertex
                    curr_vertex <= curr_vertex - 1;
                    // Restore the color of the previous vertex to current try variable to increment it
                    color_try <= colors[curr_vertex - 1] + 1;
                    state <= VERIFY_CONSTRAINT; // Wait, need to check if the restored state allows increment
                    // Actually, standard backtracking: 
                    // 1. Move to previous vertex.
                    // 2. Take its color (which is stored in colors[curr_vertex])
                    // 3. Increment that color.
                    // 4. Verify.
                    // Since I updated curr_vertex first, I need to refer to the OLD vertex value to get its color.
                    // Let's fix the order.
                    // Correct logic:
                    // Let prev = curr_vertex.
                    // curr_vertex <= prev - 1;
                    // color_try <= colors[prev - 1] + 1 -> Wait, colors[prev] is the color of the vertex we are backtracking FROM? 
                    // No, colors[curr_vertex] is the color of the vertex we are currently AT (the one we want to change).
                    // So: We are at vertex C. We failed all colors. We backtrack to C-1.
                    // We want to increment the color of C-1.
                    // So: new C = C-1. New color_try = colors[C-1] + 1.
                    // But C-1 hasn't changed yet. So: color_try <= colors[C-1] + 1 is correct.
                    // However, I changed curr_vertex before using it to index colors.
                    // Let's rewrite BACKTRACK state logic carefully.
                end

                FOUND_SOLUTION: begin
                    chromatic_number <= k;
                    state <= DONE;
                end

                INCREMENT_K: begin
                    k <= k + 1;
                    state <= CHECK_K;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to reset or accept new start
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Logic for Constraint Check
    // We split BACKTRACK logic and Constraint check combinational outputs.
    // The state machine above is synchronous, but constraint check requires combinational logic
    // to make decisions in the VERIFY state.
    
    // Fix BACKTRACK state synchronous behavior:
    // Since BACKTRACK is a single cycle state, it sets up values for VERIFY.
    // We need to handle the index correction here or modify the state transition logic.
    // Let's use an always_comb block for next_state to handle complex backtracking logic cleanly.
    
    // Re-defining state transition logic with Combinational Next State logic
    reg [4:0] state_reg;
    // We will use the standard Moore/Mealy approach.
    // Actually, let's just use the always_comb for next_state to fix the BACKTRACK issue and COND logic.
    
    // Registers to hold state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state_reg <= IDLE;
        else state_reg <= next_state;
    end

    // Combinational Logic
    always @(*) begin
        next_state = state_reg; // Default hold
        
        case (state_reg)
            IDLE: begin
                if (start) next_state = INIT_COLOR_K;
            end

            INIT_COLOR_K: begin
                next_state = CHECK_K;
            end

            CHECK_K: begin
                if (k > num_vertices) next_state = DONE; 
                else next_state = SETUP_BACKTRACK;
            end

            SETUP_BACKTRACK: begin
                next_state = ASSIGN_COLOR;
            end

            ASSIGN_COLOR: begin
                next_state = VERIFY_CONSTRAINT;
            end

            VERIFY_CONSTRAINT: begin
                // Use combinational violation signal
                if (constraint_violated) begin
                    if (color_try + 1 < k) begin
                        next_state = ASSIGN_COLOR; // Try next color (color_try updated in seq logic on edge)
                    end else begin
                        if (curr_vertex == 0) begin
                            next_state = INCREMENT_K;
                        end else begin
                            next_state = BACKTRACK;
                        end
                    end
                end else begin // Valid assignment
                    if (curr_vertex == num_vertices - 1) begin
                        next_state = FOUND_SOLUTION;
                    end else begin
                        next_state = NEXT_VERTEX;
                    end
                end
            end

            BACKTRACK: begin
                // This state is transitional. It calculates the next state based on restored values.
                // But we need to see if the restored + 1 is valid. 
                // Ideally, we just set up the values (curr_vertex, color_try) and go to VERIFY.
                // However, VERIFY logic checks 'color_try' against adjacency.
                // We need to calculate the restored color_try in combinational logic?
                // Or we can do it in BACKTRACK state and transition to VERIFY.
                // Let's do: BACKTRACK updates registers. VERIFY checks.
                // But BACKTRACK is a state. We need to update registers in BACKTRACK or move to a state that does.
                // Since we are in Combinational block for next_state, we can't update registers.
                // So we need to handle this via the sequential logic updates in BACKTRACK state, or
                // assume BACKTRACK takes 1 cycle to update indices, then VERIFY checks.
                // But VERIFY logic relies on 'color_try'. 
                // Let's keep BACKTRACK as a state that sets up 'curr_vertex' and 'color_try' for the next cycle.
                // Then we go to VERIFY. 
                // Wait, if we go to VERIFY, we need 'constraint_violated' to be evaluated.
                // If BACKTRACK updates registers on the clock edge, and then we go to VERIFY, we are good.
                // However, the transition from BACKTRACK to VERIFY means BACKTRACK is a state.
                // In BACKTRACK state (active), we update registers.
                // In the next cycle (VERIFY), we check.
                // So: BACKTRACK -> ASSIGN_COLOR (if we update color_try there) or BACKTRACK -> VERIFY (if color_try is pre-calc).
                // Let's make BACKTRACK update 'curr_vertex' and 'color_try' (restore + increment).
                // Then go to VERIFY. 
                // But the 'constraint_violated' check needs to be active in the cycle after BACKTRACK.
                // So: Next state after BACKTRACK should be VERIFY (if we update registers in BACKTRACK),
                // OR we need a cycle to update registers.
                // Let's do: BACKTRACK updates registers. Next state is VERIFY.
                // Since registers update on clock edge, VERIFY logic will see the updated values.
                // So: BACKTRACK -> VERIFY (with updated registers).
                next_state = VERIFY_CONSTRAINT;
            end

            NEXT_VERTEX: begin
                next_state = ASSIGN_COLOR;
            end

            FOUND_SOLUTION: begin
                next_state = DONE;
            end

            INCREMENT_K: begin
                next_state = CHECK_K;
            end

            DONE: begin
                if (!start) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic for Outputs and Registers
    // We combine the state update and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chromatic_number <= 3'b0;
            done <= 1'b0;
            k <= 3'b0;
            curr_vertex <= 3'b0;
            color_try <= 3'b0;
            // colors not reset here to save gates, but valid only during computation
        end else begin
            // Default assignments (keep state unless changed)
            state_reg <= next_state;
            
            // Handle updates for specific states
            case (next_state)
                INIT_COLOR_K: begin
                    k <= 3'b001;
                end
                
                SETUP_BACKTRACK: begin
                    curr_vertex <= 3'b000;
                    color_try <= 3'b000;
                end
                
                ASSIGN_COLOR: begin
                    // Logic handled in VERIFY usually, but if we came from NEXT_VERTEX, color_try is 0.
                    // If we came from VERIFY (retry), color_try is already incremented.
                    // No specific update needed here, just transition.
                end
                
                BACKTRACK: begin
                    // Update pointers and colors here
                    if (curr_vertex > 0) begin
                        curr_vertex <= curr_vertex - 1;
                        // Restore color of the vertex we are moving back to (which is now curr_vertex - 1)
                        // Wait, we update curr_vertex first. So to get the OLD vertex color, we need to subtract 1 from the NEW curr_vertex.
                        // OLD = curr_vertex. NEW = OLD - 1.
                        // We want to increment colors[OLD].
                        // But we updated curr_vertex to NEW. So NEW is curr_vertex.
                        // So we want to increment colors[curr_vertex].
                        // But colors[curr_vertex] is the color of the vertex we just left? 
                        // No. Colors[curr_vertex] where curr_vertex is the index of the vertex.
                        // We are moving from vertex I+1 to I. We want to change color of I.
                        // colors[I] is the stored color of I.
                        // We want new color_try for I to be colors[I] + 1.
                        // So: color_try <= colors[curr_vertex] + 1. (curr_vertex is now I).
                        color_try <= colors[curr_vertex] + 1; 
                    end
                end
                
                NEXT_VERTEX: begin
                    // Move to next vertex, reset color try to 0
                    curr_vertex <= curr_vertex + 1;
                    color_try <= 3'b000;
                end
                
                VERIFY_CONSTRAINT: begin
                    // If valid assignment, we store the color into the array
                    if (!constraint_violated) begin
                        colors[curr_vertex] <= color_try;
                    end
                    // If invalid and we retry (color_try++), logic is in state transition, but we might need to update color_try here?
                    // Wait, in VERIFY we decide next state. 
                    // If we stay in VERIFY or go to ASSIGN_COLOR with incremented color, we need to increment color_try.
                    // The state logic above says: if violation, if color_try + 1 < k, next_state = ASSIGN_COLOR.
                    // But color_try increment must happen.
                    // So we can do: if violation && color_try+1 < k -> color_try <= color_try + 1.
                    // Since this is always block triggered by next_state, we can put the update here.
                    if (constraint_violated && (color_try + 1 < k)) begin
                        color_try <= color_try + 1;
                    end
                end
                
                INCREMENT_K: begin
                    k <= k + 1;
                end
                
                FOUND_SOLUTION: begin
                    chromatic_number <= k;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                IDLE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Constraint Violation Combinational Logic
    always @(*) begin
        constraint_violated = 1'b0;
        // Check against all previously assigned vertices
        for (i = 0; i < 8; i = i + 1) begin
            if (i < num_vertices && i < curr_vertex) begin
                // Check edge
                if (adjacency_matrix[curr_vertex][i] == 1'b1) begin
                    // Check color conflict
                    if (colors[i] == color_try) begin
                        constraint_violated = 1'b1;
                    end
                end
                // Also check symmetric edge if matrix is not strictly upper triangular?
                // Usually adjacency matrix for coloring is symmetric. 
                // Input description says "matrix[u][v] == 1". 
                // To be safe, check adjacency_matrix[curr_vertex][i] and adjacency_matrix[i][curr_vertex]
                // But we only have access to rows. Input is [7:0] adjacency_matrix [0:7][0:7].
                // So adjacency_matrix[curr_vertex][i] is the edge from curr_vertex to i.
                // If the graph is undirected, the matrix should be symmetric.
                // We trust the input provides the correct edge relation for (u, v).
            end
        end
    end

endmodule