module stick_sorter (
    input clk,
    input rst_n,
    input start,
    input [15:0] s0_x1, s0_y1, s0_x2, s0_y2,
    input [15:0] s1_x1, s1_y1, s1_x2, s1_y2,
    input [15:0] s2_x1, s2_y1, s2_x2, s2_y2,
    input [15:0] s3_x1, s3_y1, s3_x2, s3_y2,
    input [15:0] s4_x1, s4_y1, s4_x2, s4_y2,
    input [15:0] s5_x1, s5_y1, s5_x2, s5_y2,
    input [15:0] s6_x1, s6_y1, s6_x2, s6_y2,
    input [15:0] s7_x1, s7_y1, s7_x2, s7_y2,
    input [2:0] n_sticks,
    output reg [3:0] order_0,
    output reg [3:0] order_1,
    output reg [3:0] order_2,
    output reg [3:0] order_3,
    output reg [3:0] order_4,
    output reg [3:0] order_5,
    output reg [3:0] order_6,
    output reg [3:0] order_7,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam COMPUTE_DEPS = 3'b001;
    localparam FIND_NEXT = 3'b010;
    localparam UPDATE_REMOVED = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Storage for sticks (unpack inputs to arrays for easier access)
    reg [15:0] sticks_x1 [0:7];
    reg [15:0] sticks_y1 [0:7];
    reg [15:0] sticks_x2 [0:7];
    reg [15:0] sticks_y2 [0:7];
    reg [2:0] current_n;

    // Dependency Matrix: dep[i][j] = 1 means i blocks j
    reg [7:0] dep_matrix [0:7];

    // Removal status: removed[i] = 1 means stick i is removed
    reg [7:0] removed;

    // Order index counter
    reg [2:0] order_idx;

    // Helper variables for combinational logic
    reg [2:0] i, j, k;
    reg [2:0] sel_idx;
    reg found_next;

    // Intermediate values for overlap and height check
    reg [15:0] max_x_i, min_x_i, avg_y_i;
    reg [15:0] max_x_j, min_x_j, avg_y_j;
    reg overlap;
    reg higher;

    // Update State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Reset output registers
            order_0 <= 4'hF;
            order_1 <= 4'hF;
            order_2 <= 4'hF;
            order_3 <= 4'hF;
            order_4 <= 4'hF;
            order_5 <= 4'hF;
            order_6 <= 4'hF;
            order_7 <= 4'hF;
            done <= 1'b0;
            // Clear storage
            current_n <= 3'b0;
            removed <= 8'b0;
            order_idx <= 3'b0;
        end else begin
            state <= next_state;

            // Default done is low unless in DONE state
            if (state != DONE) done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Latch inputs
                        sticks_x1[0] <= s0_x1; sticks_y1[0] <= s0_y1; sticks_x2[0] <= s0_x2; sticks_y2[0] <= s0_y2;
                        sticks_x1[1] <= s1_x1; sticks_y1[1] <= s1_y1; sticks_x2[1] <= s1_x2; sticks_y2[1] <= s1_y2;
                        sticks_x1[2] <= s2_x1; sticks_y1[2] <= s2_y1; sticks_x2[2] <= s2_x2; sticks_y2[2] <= s2_y2;
                        sticks_x1[3] <= s3_x1; sticks_y1[3] <= s3_y1; sticks_x2[3] <= s3_x2; sticks_y2[3] <= s3_y2;
                        sticks_x1[4] <= s4_x1; sticks_y1[4] <= s4_y1; sticks_x2[4] <= s4_x2; sticks_y2[4] <= s4_y2;
                        sticks_x1[5] <= s5_x1; sticks_y1[5] <= s5_y1; sticks_x2[5] <= s5_x2; sticks_y2[5] <= s5_y2;
                        sticks_x1[6] <= s6_x1; sticks_y1[6] <= s6_y1; sticks_x2[6] <= s6_x2; sticks_y2[6] <= s6_y2;
                        sticks_x1[7] <= s7_x1; sticks_y1[7] <= s7_y1; sticks_x2[7] <= s7_x2; sticks_y2[7] <= s7_y2;
                        current_n <= n_sticks;
                        removed <= 8'b0;
                        order_idx <= 3'b0;
                        // Clear output registers (optional, or just overwrite)
                    end
                end

                COMPUTE_DEPS: begin
                    // Logic handled inside combinational block for next_state transition
                    // We need to actually write to dep_matrix here in sequential logic
                    // However, to save logic depth, we do it step-by-step or assume "always_comb" handles triggers.
                    // Since standard Verilog requires procedural assignment in sequential block for storage:
                    // We will use the combinational block below to compute values, but here we sample them.
                    // Actually, for an 8x8 matrix, doing it in one cycle is fine.
                    // The combinational block `comb_logic` will calculate `dep_matrix_calc`.
                    // We assign it here:
                    dep_matrix <= dep_matrix_calc;
                end

                FIND_NEXT: begin
                    // Logic handled in combinational block (sel_idx, found_next)
                    // No register update needed here, just reading
                end

                UPDATE_REMOVED: begin
                    if (found_next && order_idx < current_n) begin
                        // Record output
                        case (order_idx)
                            3'd0: order_0 <= {1'b0, sel_idx};
                            3'd1: order_1 <= {1'b0, sel_idx};
                            3'd2: order_2 <= {1'b0, sel_idx};
                            3'd3: order_3 <= {1'b0, sel_idx};
                            3'd4: order_4 <= {1'b0, sel_idx};
                            3'd5: order_5 <= {1'b0, sel_idx};
                            3'd6: order_6 <= {1'b0, sel_idx};
                            3'd7: order_7 <= {1'b0, sel_idx};
                        endcase
                        
                        // Mark removed
                        removed[sel_idx] <= 1'b1;
                        
                        // Update dependency matrix: remove outgoing edges from selected stick
                        // In Verilog, we can't easily do array assignment like dep_matrix[sel_idx] <= 0;
                        // So we update the array elements conditionally
                        for (int idx = 0; idx < 8; idx++) begin
                            if (idx == sel_idx) dep_matrix[idx] <= 8'b0;
                        end
                        
                        order_idx <= order_idx + 1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic for State Transitions and Computations
    reg [7:0] dep_matrix_calc [0:7];
    
    always @(*) begin
        // Default State
        next_state = state;
        
        // Default calc for dep_matrix
        // Initialize calc matrix to current matrix or compute fresh
        // If state is not COMPUTE_DEPS, we might just pass through current values
        for (int q = 0; q < 8; q++) dep_matrix_calc[q] = dep_matrix[q];

        // Default selection vars
        sel_idx = 0;
        found_next = 1'b0;

        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_DEPS;
            end

            COMPUTE_DEPS: begin
                // Calculate new dependency matrix based on latched inputs
                // This is combinational logic for the matrix calculation
                for (int r = 0; r < 8; r++) begin
                    dep_matrix_calc[r] = 8'b0;
                end

                for (int ii = 0; ii < 8; ii++) begin
                    // Only compute if stick is valid (though inputs are always there, n_sticks controls validity)
                    // But we strictly follow N. If ii >= n_sticks, we leave deps 0 (or implicitly unused)
                    if (ii < current_n) begin
                        // Pre-calculate stats for stick ii
                        max_x_i = (sticks_x1[ii] > sticks_x2[ii]) ? sticks_x1[ii] : sticks_x2[ii];
                        min_x_i = (sticks_x1[ii] < sticks_x2[ii]) ? sticks_x1[ii] : sticks_x2[ii];
                        avg_y_i = (sticks_y1[ii] + sticks_y2[ii]) >> 1; // Shift for divide by 2

                        for (int jj = 0; jj < 8; jj++) begin
                            if (jj < current_n && ii != jj) begin
                                // Pre-calculate stats for stick jj
                                max_x_j = (sticks_x1[jj] > sticks_x2[jj]) ? sticks_x1[jj] : sticks_x2[jj];
                                min_x_j = (sticks_x1[jj] < sticks_x2[jj]) ? sticks_x1[jj] : sticks_x2[jj];
                                avg_y_j = (sticks_y1[jj] + sticks_y2[jj]) >> 1;

                                // Check Overlap: max_i >= min_j && min_i <= max_j
                                overlap = (max_x_i >= min_x_j) && (min_x_i <= max_x_j);
                                
                                // Check Height: avg_y_i > avg_y_j
                                higher = (avg_y_i > avg_y_j);

                                if (overlap && higher) begin
                                    dep_matrix_calc[ii][jj] = 1'b1;
                                end
                            end
                        end
                    end
                end
                
                next_state = FIND_NEXT;
            end

            FIND_NEXT: begin
                // Find a stick k that is NOT removed, and has no dependencies
                found_next = 1'b0;
                sel_idx = 0;
                
                // Loop to find first valid stick
                for (int k_idx = 0; k_idx < 8; k_idx++) begin
                    if (!found_next && k_idx < current_n) begin
                        if (!removed[k_idx]) begin
                            // Check if any other stick blocks it
                            // Check if any dep_matrix[i][k_idx] == 1 for any i
                            // Actually, we need to check if any i (not removed) blocks k_idx
                            // But removed sticks are updated in matrix to 0, so just check matrix
                            
                            // Check column k_idx for any 1s in rows that are valid
                            // Since dep_matrix is updated to clear removed rows, we just check the column
                            
                            reg has_dependency = 1'b0;
                            for (int i_idx = 0; i_idx < 8; i_idx++) begin
                                if (dep_matrix[i_idx][k_idx]) begin
                                    has_dependency = 1'b1;
                                end
                            end

                            if (!has_dependency) begin
                                found_next = 1'b1;
                                sel_idx = k_idx[2:0];
                            end
                        end
                    end
                end

                if (found_next) begin
                    next_state = UPDATE_REMOVED;
                end else begin
                    // No stick found. 
                    // If all sticks are removed, go to DONE
                    // Note: order_idx tracks how many removed. 
                    // If order_idx == current_n, all removed
                    if (order_idx == current_n) begin
                        next_state = DONE;
                    end else begin
                        // Cycle detected or error. 
                        // To be robust, we can just output 0s or go to DONE.
                        // Let's go to DONE to avoid hanging.
                        next_state = DONE;
                    end
                end
            end

            UPDATE_REMOVED: begin
                // We updated registers. Transition to FIND_NEXT
                if (order_idx < current_n) begin
                    next_state = FIND_NEXT;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                // Stay here until reset
                if (start) next_state = IDLE; // Optional: allow restart without reset
                else next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
