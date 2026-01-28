module Lamp2SAT(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] lamp_row [0:15],
    input wire [3:0] lamp_col [0:15],
    input wire [3:0] num_lamps,
    input wire [3:0] grid_size,
    input wire [3:0] max_reach,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD        = 3'd1;
    localparam [2:0] INITIALIZE  = 3'd2;
    localparam [2:0] CHECK_VALID = 3'd3;
    localparam [2:0] NEXT_ASSIGN = 3'd4;
    localparam [2:0] FOUND       = 3'd5;
    localparam [2:0] EXHAUSTED   = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] current_lamp;
    reg [3:0] checked_lamp_i;
    reg [3:0] checked_lamp_j;
    reg [3:0] lamp_count_reg;
    reg [7:0] coord_i; // row * 8 + col
    reg [7:0] coord_j; // row * 8 + col
    reg [3:0] row_i, col_i, row_j, col_j;
    reg conflict_found;
    reg [15:0] assignment; // bit k: 0=row, 1=column
    reg [15:0] valid_assignments;
    reg valid_flag;
    reg [15:0] processed_lamps; // Track which lamps processed in current assignment
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLES = 4'd15;
    reg [2:0] sub_state;
    localparam [1:0] SUB_CHECK_ROW = 2'd0;
    localparam [1:0] SUB_CHECK_COL = 2'd1;
    localparam [1:0] SUB_NEXT_PAIR = 2'd2;
    localparam [1:0] SUB_DONE = 2'd3;

    // Helper logic for conflict checking
    // Checks if lamp i and lamp j conflict given their assignments
    // Conflict condition: same square is covered
    wire [7:0] i_base;
    wire [7:0] j_base;
    assign i_base = {row_i[3:0], col_i[3:0]}; // pack row and col for easy comparison
    assign j_base = {row_j[3:0], col_j[3:0]};

    // Check row conflict: both in row mode, overlapping reach
    wire row_conflict;
    assign row_conflict = (row_i == row_j) && 
                          ( (col_i > col_j) ? (col_i - col_j <= max_reach) : (col_j - col_i <= max_reach) );

    // Check column conflict: both in col mode, overlapping reach
    wire col_conflict;
    assign col_conflict = (col_i == col_j) && 
                          ( (row_i > row_j) ? (row_i - row_j <= max_reach) : (row_j - row_i <= max_reach) );

    // Update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            current_lamp <= 4'd0;
            checked_lamp_i <= 4'd0;
            checked_lamp_j <= 4'd0;
            lamp_count_reg <= 4'd0;
            coord_i <= 8'd0;
            coord_j <= 8'd0;
            row_i <= 4'd0;
            col_i <= 4'd0;
            row_j <= 4'd0;
            col_j <= 4'd0;
            conflict_found <= 1'b0;
            assignment <= 16'd0;
            valid_assignments <= 16'd0;
            valid_flag <= 1'b0;
            processed_lamps <= 16'd0;
            cycle_counter <= 4'd0;
            sub_state <= SUB_DONE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        current_lamp <= 4'd0;
                        lamp_count_reg <= num_lamps;
                    end
                end

                LOAD: begin
                    // Load lamps is implicit as inputs are registered
                    // Just need to initialize for search
                    state <= INITIALIZE;
                    assignment <= 16'd0; // Start with all row mode
                    cycle_counter <= 4'd0;
                end

                INITIALIZE: begin
                    // Initialize check variables
                    checked_lamp_i <= 4'd0;
                    checked_lamp_j <= 4'd1;
                    conflict_found <= 1'b0;
                    valid_flag <= 1'b1;
                    sub_state <= SUB_CHECK_ROW;
                    state <= CHECK_VALID;
                end

                CHECK_VALID: begin
                    case (sub_state)
                        SUB_CHECK_ROW: begin
                            // Load lamp i data
                            row_i <= lamp_row[checked_lamp_i];
                            col_i <= lamp_col[checked_lamp_i];
                            // Load lamp j data
                            row_j <= lamp_row[checked_lamp_j];
                            col_j <= lamp_col[checked_lamp_j];
                            sub_state <= SUB_CHECK_COL;
                        end

                        SUB_CHECK_COL: begin
                            // Determine if there is a conflict
                            if (checked_lamp_j < lamp_count_reg) begin
                                // Check assignments for these lamps
                                if ((assignment[checked_lamp_i] == 1'b0) && (assignment[checked_lamp_j] == 1'b0)) begin
                                    // Both row mode - check row conflict
                                    if (row_conflict) begin
                                        conflict_found <= 1'b1;
                                        valid_flag <= 1'b0;
                                        state <= NEXT_ASSIGN;
                                    end else begin
                                        sub_state <= SUB_NEXT_PAIR;
                                    end
                                end else if ((assignment[checked_lamp_i] == 1'b1) && (assignment[checked_lamp_j] == 1'b1)) begin
                                    // Both col mode - check col conflict
                                    if (col_conflict) begin
                                        conflict_found <= 1'b1;
                                        valid_flag <= 1'b0;
                                        state <= NEXT_ASSIGN;
                                    end else begin
                                        sub_state <= SUB_NEXT_PAIR;
                                    end
                                end else begin
                                    // Different modes, no direct conflict from these
                                    sub_state <= SUB_NEXT_PAIR;
                                end
                            end else begin
                                sub_state <= SUB_NEXT_PAIR;
                            end
                        end

                        SUB_NEXT_PAIR: begin
                            if (checked_lamp_j < lamp_count_reg - 1) begin
                                checked_lamp_j <= checked_lamp_j + 4'd1;
                                sub_state <= SUB_CHECK_ROW;
                            end else begin
                                // Move to next i
                                if (checked_lamp_i < lamp_count_reg - 2) begin
                                    checked_lamp_i <= checked_lamp_i + 4'd1;
                                    checked_lamp_j <= checked_lamp_i + 4'd2;
                                    sub_state <= SUB_CHECK_ROW;
                                end else begin
                                    // All pairs checked
                                    sub_state <= SUB_DONE;
                                end
                            end
                        end

                        SUB_DONE: begin
                            if (valid_flag) begin
                                state <= FOUND;
                            end else begin
                                state <= NEXT_ASSIGN;
                            end
                        end
                    endcase
                end

                NEXT_ASSIGN: begin
                    // Generate next lexicographic assignment (binary increment)
                    // Iterate: 0000 -> 0001 -> 0010 -> ...
                    // Check if we have exhausted all 2^num_lamps possibilities
                    
                    // We need to iterate 'num_lamps' bits.
                    // The bits higher than num_lamps-1 should be ignored (always 0)
                    
                    // Check if we reached max (all 1s for valid bits)
                    // Build mask for valid bits
                    // Since k<=16, we can check cycle counter or value
                    // To be safe, we just check the bits.
                    
                    // Increment assignment
                    assignment <= assignment + 16'd1;
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    // Check if we rolled over the valid bits or hit limit
                    // For k lamps, we check bits [k-1:0]. If they are all 1, next is 0 with carry.
                    // We can stop if the lower k bits are all 0 again (wrapped around) OR we hit a max cycle limit.
                    
                    // Verify: Does the new assignment only use valid bits?
                    // The loop simply increments. If we increment past (1<<k)-1, bits k-1:0 become 0.
                    // So we stop if bits [k-1:0] == 0 and we are not at the start.
                    
                    if (assignment[lamp_count_reg-1:0] == 0 && cycle_counter > 0) begin
                        // Wrapped around or exhausted
                        state <= EXHAUSTED;
                    end else begin
                        // Re-check validity
                        checked_lamp_i <= 4'd0;
                        checked_lamp_j <= 4'd1;
                        conflict_found <= 1'b0;
                        valid_flag <= 1'b1;
                        sub_state <= SUB_CHECK_ROW;
                        state <= CHECK_VALID;
                    end
                end

                FOUND: begin
                    result <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                EXHAUSTED: begin
                    result <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule