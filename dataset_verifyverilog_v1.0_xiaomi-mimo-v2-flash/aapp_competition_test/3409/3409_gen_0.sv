module peg_hammering_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] start_board [0:7],
    input wire [7:0] target_board [0:7],
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CHECK_ROW = 3'd2;
    localparam [2:0] CHECK_COL = 3'd3;
    localparam [2:0] VERIFY    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] d_matrix [0:7];       // Difference matrix S XOR T
    reg [7:0] row_parities [0:7];   // Parity of each row in D
    reg [7:0] col_parities [0:7];   // Parity of each column in D
    reg [2:0] i_idx;                // Row index
    reg [2:0] j_idx;                // Column index
    reg [2:0] counter;              // General counter
    reg [7:0] temp_xor;             // Temporary storage for parity calc
    reg parity_val;                 // Stored parity value for comparison
    reg internal_valid;             // Flag to store final validity
    reg [7:0] cycle_counter;        // Safety counter

    // Cycle limit to prevent infinite loops (100 cycles max as per spec)
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for next state and next values
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                // Done calculating D = S XOR T for all elements
                next_state = CHECK_ROW;
            end
            
            CHECK_ROW: begin
                // Wait one cycle for row parity calculation
                next_state = CHECK_COL;
            end
            
            CHECK_COL: begin
                // Wait one cycle for col parity calculation
                next_state = VERIFY;
            end
            
            VERIFY: begin
                // Verify parities match
                next_state = FINISH;
            end
            
            FINISH: begin
                // Done signal asserted, return to IDLE
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            internal_valid <= 1'b0;
            cycle_counter <= 8'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            counter <= 3'd0;
            parity_val <= 1'b0;
            temp_xor <= 8'd0;
            // Initialize arrays to zero
            begin : init_d_matrix
                integer k;
                for (k = 0; k < 8; k = k + 1) begin
                    d_matrix[k] <= 8'd0;
                    row_parities[k] <= 8'd0;
                    col_parities[k] <= 8'd0;
                end
            end
        end else begin
            // Increment cycle counter if not IDLE or FINISH
            if (state != IDLE && state != FINISH) begin
                if (cycle_counter < MAX_CYCLES)
                    cycle_counter <= cycle_counter + 8'd1;
                else
                    state <= FINISH; // Force finish if takes too long
            end else begin
                cycle_counter <= 8'd0;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                    end
                end

                LOAD: begin
                    // Compute D[i][j] = start_board[i][j] XOR target_board[i][j]
                    // We iterate through 8x8 grid
                    // Using nested loop logic manually unrolled for clarity or step-by-step
                    // Since we can't do multi-dimensional array assignment easily in one go,
                    // we calculate row by row.
                    // Actually, let's just compute D on the fly in CHECK_ROW/CHECK_COL or precompute.
                    // Precomputation requires iterating i and j.
                    // Let's use i_idx and j_idx here to fill d_matrix.
                    
                    d_matrix[i_idx][j_idx] <= start_board[i_idx][j_idx] ^ target_board[i_idx][j_idx];
                    
                    if (j_idx < 3'd7) begin
                        j_idx <= j_idx + 3'd1;
                    end else begin
                        j_idx <= 3'd0;
                        if (i_idx < 3'd7) begin
                            i_idx <= i_idx + 3'd1;
                        end else begin
                            // Done computing D matrix
                            i_idx <= 3'd0;
                            state <= CHECK_ROW;
                        end
                    end
                end

                CHECK_ROW: begin
                    // Compute parity of row i_idx: XOR of all bits in d_matrix[i_idx]
                    // We can compute this in one cycle using a reduction XOR or sequential.
                    // For 8 bits, sequential is fine, or reduce.
                    // d_matrix[i_idx][0] ^ ... ^ d_matrix[i_idx][7]
                    // Let's do sequential for robustness in Icarus.
                    
                    // In this state, we just initiate calculation.
                    // We need to store the parity result.
                    // Since we are in a cycle, we calculate temp_xor.
                    
                    // Wait, to keep it simple and within logic, let's compute row parities
                    // in the next state (CHECK_COL) effectively, or use combinational logic.
                    // Given the strict rules, let's compute row parity for all rows in one go
                    // or just check constraints.
                    
                    // Let's compute row parity for row i_idx in this state.
                    // Actually, it's easier to compute all row parities in a loop
                    // before moving to CHECK_COL.
                    
                    // Re-evaluating logic: 
                    // The condition is D[i1][j1] ^ D[i1][j2] ^ D[i2][j1] ^ D[i2][j2] == 0.
                    // This implies (RowParity[i1] ^ ColParity[j1] ^ D[i1][j1] ... ) 
                    // Actually, simpler condition: 
                    // All row parities must be equal, AND all column parities must be equal.
                    // AND the sum of row parities must match sum of column parities (mod 2).
                    // Let's compute row parities.
                    
                    // We will compute row_parities[i_idx] in this state.
                    temp_xor <= d_matrix[i_idx][0] ^ d_matrix[i_idx][1] ^ d_matrix[i_idx][2] ^ d_matrix[i_idx][3] ^
                                d_matrix[i_idx][4] ^ d_matrix[i_idx][5] ^ d_matrix[i_idx][6] ^ d_matrix[i_idx][7];
                    
                    // Next cycle, store it.
                    // We need a dedicated state to store row parities or do it in the transition.
                    // Let's add a state or piggyback.
                    // We'll advance i_idx in the next state (CHECK_COL is next), 
                    // so we need to save temp_xor.
                end

                CHECK_COL: begin
                    // Save row parity computed in previous cycle
                    // Note: temp_xor is the row parity for i_idx (from CHECK_ROW state)
                    // We need to increment i_idx here to cover all 8 rows.
                    // To do this properly, we need to loop CHECK_ROW -> CHECK_COL -> CHECK_ROW...
                    // Or compute all at once.
                    
                    // Let's adjust the flow:
                    // State CHECK_ROW: Compute temp_xor for current i_idx.
                    // Transition to CHECK_COL: Save row_parities[i_idx], increment i_idx.
                    // If i_idx < 7, go back to CHECK_ROW. Else go to CHECK_COL state (phase 2).
                    
                    // However, the state transition is fixed. 
                    // Let's modify the logic to compute one row per cycle in LOAD/CHECK phases.
                    // Actually, simpler: Compute all row parities in LOAD or a specific state.
                    // Let's compute row parities for all rows in the CHECK_ROW state (looping)
                    // and column parities in CHECK_COL state (looping).
                    
                    // Let's use a counter to track progress inside states.
                    
                    // Correction: Let's compute row parities first.
                    // Row Parity Calculation (8 cycles):
                    // When entering CHECK_ROW, i_idx starts at 0.
                    // We calculate parity for row i_idx.
                    // We save it.
                    // If i_idx < 7, increment i_idx and stay in CHECK_ROW (loop).
                    // If i_idx == 7, move to CHECK_COL (reset i_idx to 0).
                    
                    // Let's redo the CHECK_ROW logic:
                    // (We are in CHECK_ROW now)
                    row_parities[i_idx] <= {d_matrix[i_idx][7], d_matrix[i_idx][6], d_matrix[i_idx][5], d_matrix[i_idx][4],
                                             d_matrix[i_idx][3], d_matrix[i_idx][2], d_matrix[i_idx][1], d_matrix[i_idx][0]};
                    // Wait, I need to calculate the parity bit, not the whole row.
                    // Parity is XOR of all bits.
                    // Let's store the XOR result.
                    row_parities[i_idx] <= d_matrix[i_idx][0] ^ d_matrix[i_idx][1] ^ d_matrix[i_idx][2] ^ d_matrix[i_idx][3] ^
                                            d_matrix[i_idx][4] ^ d_matrix[i_idx][5] ^ d_matrix[i_idx][6] ^ d_matrix[i_idx][7];
                    
                    // This logic above is combinational, but we are in a sequential block.
                    // We need to set it up in the previous state or use combinational logic.
                    // Let's assume we calculated it in previous cycle.
                    
                    // Better approach for Icarus compatibility:
                    // Use 'counter' to iterate 0 to 7 inside the CHECK_ROW and CHECK_COL states.
                    
                    // Let's restart the implementation strategy for the checking phase:
                    // Phase 1: Calculate row parities.
                    //   Enter CHECK_ROW with counter = 0.
                    //   In CHECK_ROW: Calculate parity of d_matrix[counter].
                    //   Wait one cycle? No, do it directly.
                    //   Store in row_parities[counter].
                    //   If counter < 7, counter++ and stay in CHECK_ROW.
                    //   If counter == 7, go to CHECK_COL, reset counter = 0.
                    // Phase 2: Calculate col parities.
                    //   Similar logic.
                    // Phase 3: Verify.
                    //   Check if all row_parities are equal.
                    //   Check if all col_parities are equal.
                    //   Check if row_parities[0] == col_parities[0].

                    // Let's rewrite the CHECK_ROW state logic here:
                    // We need to compute XOR of 8 bits. 
                    // d_matrix[counter] is 8 bits.
                    // We can do reduction XOR.
                    
                    // Let's calculate the parity for row 'counter' now.
                    // Since it's combinational in always block, we can assign it.
                    // But we need to store it in the register.
                    
                    // Let's do this:
                    // row_parities[counter] <= d_matrix[counter][0] ^ ... ^ d_matrix[counter][7];
                    // But 'counter' might be updated in the same cycle if we aren't careful.
                    // Wait, sequential block updates on clock edge.
                    // The RHS is evaluated with current 'counter'.
                    
                    // Let's add a state to compute row parities.
                    // Actually, let's combine it. 
                    // We will iterate 'counter' from 0 to 7 in CHECK_ROW.
                    // In CHECK_ROW state:
                    //   row_parities[counter] <= d_matrix[counter][0] ^ d_matrix[counter][1] ^ ... ^ d_matrix[counter][7];
                    //   if (counter < 7) counter <= counter + 1; else state <= CHECK_COL;
                    
                    // Let's implement this.
                end

                VERIFY: begin
                    // Check constraints
                    // 1. All row parities equal?
                    // 2. All col parities equal?
                    // 3. Row parity == Col parity?
                    
                    // Since we have 8 elements, we can check sequentially or by logic.
                    // Let's check row parities: r_p[0] == r_p[1] == ... == r_p[7]
                    // We can check r_p[0] == r_p[i] for i=1..7
                    
                    // Check 1: Row Parity Consistency
                    if ( (row_parities[0] == row_parities[1]) &&
                         (row_parities[0] == row_parities[2]) &&
                         (row_parities[0] == row_parities[3]) &&
                         (row_parities[0] == row_parities[4]) &&
                         (row_parities[0] == row_parities[5]) &&
                         (row_parities[0] == row_parities[6]) &&
                         (row_parities[0] == row_parities[7]) )
                    begin
                        internal_valid <= 1'b1; // Tentative
                    end else begin
                        internal_valid <= 1'b0;
                    end
                end

                FINISH: begin
                    // Finalize result
                    // We need to incorporate the other checks (column consistency and match)
                    // into the internal_valid update.
                    // Let's compute the full condition in VERIFY state.
                    
                    // Move logic here: 
                    // Actually, VERIFY state should compute everything, then FINISH asserts done.
                    // We will calculate final result in VERIFY state.
                end
            endcase
            
            // Correction to handle loops within states properly without 'break':
            // We need to rewrite CHECK_ROW and CHECK_COL to handle the iteration.
            
            // RE-IMPLEMENTATION of CHECK_ROW (Iterate 0 to 7):
            // We need a dedicated state for row calc and one for col calc.
            // Let's rename states: CHECK_ROW (calc row), CHECK_COL (calc col), VERIFY (check).
            // Actually, let's just use CHECK_ROW to fill row_parities array.
            // And CHECK_COL to fill col_parities array.
        end
    end

    // To make this robust and correct given the complexity, 
    // let's re-verify the sequential block logic carefully.
    // The previous block had logic split. Let's condense it for correctness.
    
    // Re-write the main sequential block cleanly:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_counter <= 8'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            counter <= 3'd0;
            begin : reset_arrays
                integer k;
                for (k = 0; k < 8; k = k + 1) begin
                    d_matrix[k] <= 8'd0;
                    row_parities[k] <= 8'd0;
                    col_parities[k] <= 8'd0;
                end
            end
        end else begin
            // Default assignments
            done <= 1'b0;
            
            if (state != IDLE && state != FINISH) begin
                if (cycle_counter < MAX_CYCLES) cycle_counter <= cycle_counter + 8'd1;
                else state <= FINISH;
            end

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                        cycle_counter <= 8'd0;
                    end
                end

                LOAD: begin
                    // Calculate D[i][j]
                    d_matrix[i_idx][j_idx] <= start_board[i_idx][j_idx] ^ target_board[i_idx][j_idx];
                    
                    if (j_idx < 3'd7) begin
                        j_idx <= j_idx + 3'd1;
                    end else begin
                        j_idx <= 3'd0;
                        if (i_idx < 3'd7) begin
                            i_idx <= i_idx + 3'd1;
                        end else begin
                            state <= CHECK_ROW;
                            counter <= 3'd0; // Use counter for row index
                        end
                    end
                end

                CHECK_ROW: begin
                    // Calculate row parity for row 'counter'
                    // d_matrix[counter] is 8 bits. We need XOR of all bits.
                    // Due to Verilog rules, let's compute it and store.
                    // We can use a reduction XOR.
                    row_parities[counter] <= ^d_matrix[counter];
                    
                    if (counter < 3'd7) begin
                        counter <= counter + 3'd1;
                        // Stay in CHECK_ROW
                    end else begin
                        // Done with rows
                        state <= CHECK_COL;
                        counter <= 3'd0; // Reset counter for column index
                    end
                end

                CHECK_COL: begin
                    // Calculate col parity for col 'counter'
                    // We need XOR of d_matrix[0][counter] ... d_matrix[7][counter]
                    // We can do this by reduction of a constructed vector or loop.
                    // Since we can't loop inside combinational easily for array slices in Icarus,
                    // let's construct the column vector and reduce it.
                    // col_vector = {d_matrix[7][counter], ..., d_matrix[0][counter]}
                    
                    // Wait, d_matrix is [7:0][7:0].
                    // To access column 'counter', we need d_matrix[k][counter].
                    // We can construct an 8-bit vector on the fly.
                    
                    col_parities[counter] <= d_matrix[0][counter] ^ d_matrix[1][counter] ^ d_matrix[2][counter] ^ d_matrix[3][counter] ^
                                              d_matrix[4][counter] ^ d_matrix[5][counter] ^ d_matrix[6][counter] ^ d_matrix[7][counter];
                    
                    if (counter < 3'd7) begin
                        counter <= counter + 3'd1;
                        // Stay in CHECK_COL
                    end else begin
                        state <= VERIFY;
                    end
                end

                VERIFY: begin
                    // Check 1: All row parities equal to row_parities[0]?
                    // Check 2: All col parities equal to col_parities[0]?
                    // Check 3: row_parities[0] == col_parities[0]?
                    
                    if ( (row_parities[0] == row_parities[1]) &&
                         (row_parities[0] == row_parities[2]) &&
                         (row_parities[0] == row_parities[3]) &&
                         (row_parities[0] == row_parities[4]) &&
                         (row_parities[0] == row_parities[5]) &&
                         (row_parities[0] == row_parities[6]) &&
                         (row_parities[0] == row_parities[7]) &&
                         (col_parities[0] == col_parities[1]) &&
                         (col_parities[0] == col_parities[2]) &&
                         (col_parities[0] == col_parities[3]) &&
                         (col_parities[0] == col_parities[4]) &&
                         (col_parities[0] == col_parities[5]) &&
                         (col_parities[0] == col_parities[6]) &&
                         (col_parities[0] == col_parities[7]) &&
                         (row_parities[0] == col_parities[0]) )
                    begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
