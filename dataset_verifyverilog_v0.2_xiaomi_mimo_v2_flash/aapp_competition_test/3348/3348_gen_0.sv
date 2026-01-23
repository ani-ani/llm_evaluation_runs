module bonbon_arrangement (
    input clk,
    input rst_n,
    input start,
    input [3:0] count_a,
    input [3:0] count_b,
    input [3:0] count_c,
    output reg [31:0] grid_packed,
    output reg valid,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SEARCH = 3'b001;
    localparam BACKTRACK = 3'b010;
    localparam VALID_STATE = 3'b011;
    localparam COMPLETE = 3'b100;

    // Grid memory (16 positions, 2 bits per position)
    reg [1:0] grid_reg [0:15];
    
    // Stack for backtracking
    reg [3:0] stack_count_a [0:15];
    reg [3:0] stack_count_b [0:15];
    reg [3:0] stack_count_c [0:15];
    reg [4:0] stack_tried [0:15]; // Bitmask: bit0=A, bit1=B, bit2=C. Values: 1, 3, 7.
    
    // Current state
    reg [2:0] state;
    reg [4:0] idx; // 0 to 15, but need 16 for 'done' check
    reg [3:0] cur_a, cur_b, cur_c;
    reg [4:0] tried_mask;
    
    // Constraint check signals (Combinational)
    wire [1:0] left_val;
    wire [1:0] top_val;
    wire left_exists;
    wire top_exists;
    wire allow_A, allow_B, allow_C;
    
    // Extract row and column
    wire [1:0] row = idx[3:2];
    wire [1:0] col = idx[1:0];
    
    // Boundary checks
    assign left_exists = (col != 0);
    assign top_exists = (row != 0);
    
    // Read neighbor values safely
    // Note: We only read neighbors when idx > 0 and neighbor index < idx.
    // Since idx is the NEXT cell to fill, neighbors are valid in grid_reg.
    assign left_val = grid_reg[idx - 1];
    assign top_val = grid_reg[idx - 4];
    
    // Determine valid placements based on constraints
    // Check Left: if left exists, it must not be the same as candidate
    // Check Top: if top exists, it must not be the same as candidate
    assign allow_A = (!left_exists || left_val != 2'd0) && (!top_exists || top_val != 2'd0);
    assign allow_B = (!left_exists || left_val != 2'd1) && (!top_exists || top_val != 2'd1);
    assign allow_C = (!left_exists || left_val != 2'd2) && (!top_exists || top_val != 2'd2);

    // Output packing
    integer i;
    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            grid_packed[i*2 +: 2] = grid_reg[i];
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize counts and index
                        cur_a <= count_a;
                        cur_b <= count_b;
                        cur_c <= count_c;
                        idx <= 0;
                        tried_mask <= 0;
                        // Clear grid (optional, but ensures clean start)
                        for (i = 0; i < 16; i = i + 1) grid_reg[i] <= 0;
                        
                        state <= SEARCH;
                        valid <= 0;
                        done <= 0;
                    end
                end

                SEARCH: begin
                    // If we have processed all 16 cells (idx reached 16)
                    if (idx == 16) begin
                        // We filled 0..15. Check if counts are exactly 0.
                        // (The algorithm ensures we don't overfill, but checks are good)
                        if (cur_a == 0 && cur_b == 0 && cur_c == 0) begin
                            state <= VALID_STATE;
                        end else begin
                            // Should not happen if logic is correct, but safety backtracks
                            state <= BACKTRACK;
                        end
                    end else begin
                        // Try to place a value at idx
                        
                        // Priority 1: Try A
                        if (tried_mask == 0 && cur_a > 0 && allow_A) begin
                            grid_reg[idx] <= 2'd0; // Place A
                            // Push state
                            stack_count_a[idx] <= cur_a - 1;
                            stack_count_b[idx] <= cur_b;
                            stack_count_c[idx] <= cur_c;
                            stack_tried[idx] <= 3'b001; // A tried
                            // Update current
                            cur_a <= cur_a - 1;
                            tried_mask <= 0; // Reset for next cell
                            idx <= idx + 1;
                        end
                        // Priority 2: Try B (if A failed or already tried)
                        else if (tried_mask <= 3'b001 && cur_b > 0 && allow_B) begin
                            grid_reg[idx] <= 2'd1;
                            stack_count_a[idx] <= cur_a;
                            stack_count_b[idx] <= cur_b - 1;
                            stack_count_c[idx] <= cur_c;
                            stack_tried[idx] <= 3'b011; // A, B tried
                            cur_b <= cur_b - 1;
                            tried_mask <= 0;
                            idx <= idx + 1;
                        end
                        // Priority 3: Try C
                        else if (tried_mask <= 3'b011 && cur_c > 0 && allow_C) begin
                            grid_reg[idx] <= 2'd2;
                            stack_count_a[idx] <= cur_a;
                            stack_count_b[idx] <= cur_b;
                            stack_count_c[idx] <= cur_c - 1;
                            stack_tried[idx] <= 3'b111; // All tried
                            cur_c <= cur_c - 1;
                            tried_mask <= 0;
                            idx <= idx + 1;
                        end
                        // Failure: No valid placement, need to backtrack
                        else begin
                            state <= BACKTRACK;
                        end
                    end
                end

                BACKTRACK: begin
                    // Decrement index to go back to the previous cell
                    if (idx == 0) begin
                        // Cannot backtrack further, no solution
                        valid <= 0;
                        done <= 1;
                        state <= COMPLETE;
                    end else begin
                        idx <= idx - 1;
                        // Restore state from stack
                        // Note: idx-1 is the previous cell index we are restoring to
                        cur_a <= stack_count_a[idx - 1];
                        cur_b <= stack_count_b[idx - 1];
                        cur_c <= stack_count_c[idx - 1];
                        // Restore 'tried_mask' of the PREVIOUS level
                        // The SEARCH logic will use this to skip the value we just failed on
                        tried_mask <= stack_tried[idx - 1];
                        
                        state <= SEARCH;
                    end
                end

                VALID_STATE: begin
                    valid <= 1;
                    done <= 1;
                    state <= COMPLETE;
                end

                COMPLETE: begin
                    // Remain in this state until reset
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule