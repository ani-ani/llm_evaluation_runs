module gold_leaf_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0] grid_row [15:0],
    output reg [3:0] r1,
    output reg [3:0] c1,
    output reg [3:0] r2,
    output reg [3:0] c2,
    output reg valid,
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE,
        H_CHECK,
        V_CHECK,
        D_CHECK,
        FOUND,
        DONE_STATE
    } state_t;

    state_t current_state, next_state;

    // Internal Registers for iteration
    reg [3:0] i, next_i; // Iteration variable (1-16)
    reg [3:0] j, next_j; // Secondary variable for diagonals
    reg found, next_found;
    reg valid_int, next_valid_int;
    
    // Temporary coordinates for evaluation
    reg [3:0] temp_r1, temp_c1, temp_r2, temp_c2;
    reg temp_valid;

    // Combinational Logic for checking validity
    always @(*) begin
        temp_r1 = 0;
        temp_c1 = 0;
        temp_r2 = 0;
        temp_c2 = 0;
        temp_valid = 0;

        case (current_state)
            H_CHECK: begin
                // Check horizontal fold between row i and 16-i (1-based math)
                // Logic indices: top = i-1, bottom = 15-(i-1) = 16-i
                if (i <= 15) begin
                    temp_r1 = i;
                    temp_c1 = 4'd1;
                    temp_r2 = i;
                    temp_c2 = 4'd16;
                    temp_valid = 1;
                    // Check mismatch
                    for (int k = 0; k < 16; k++) begin
                        if (grid_row[i-1][k] != grid_row[16-i][k]) begin
                            // Rule: A=1 (gold) is OK. A=0 (paper), B=1 is BAD.
                            // Top is A, Bottom is B. If Top=0 and Bottom=1, invalid.
                            if (grid_row[i-1][k] == 1'b0 && grid_row[16-i][k] == 1'b1) begin
                                temp_valid = 0;
                            end
                        end
                    end
                end
            end

            V_CHECK: begin
                // Check vertical fold between col i and 16-i
                if (i <= 15) begin
                    temp_r1 = 4'd1;
                    temp_c1 = i;
                    temp_r2 = 4'd16;
                    temp_c2 = i;
                    temp_valid = 1;
                    for (int k = 0; k < 16; k++) begin
                        // Left is grid_row[k][i-1], Right is grid_row[k][16-i]
                        if (grid_row[k][i-1] != grid_row[k][16-i]) begin
                            if (grid_row[k][i-1] == 1'b0 && grid_row[k][16-i] == 1'b1) begin
                                temp_valid = 0;
                            end
                        end
                    end
                end
            end

            D_CHECK: begin
                // Diagonal checks are ordered by (r1, c1) ascending.
                // 1. Top-Left to Bottom-Right (Main Diagonal)
                //    Lines: r - c = k. k from -15 to 15.
                //    Iterate k by setting j.
                //    Let i track the row index of the top-left pixel.
                //    i goes 0..15. j = i - k.
                //    Need to iterate k first? 
                //    Let's use i as the index for the specific diagonal line.
                //    k = i - 7 (so i=7 -> k=0). 
                //    Actually, let's follow the iteration:
                //    We iterate through all valid lines. 
                //    Variable i will represent the line index.
                //    We need to map i to actual geometric coordinates.
                
                // Let's map i (1 to 31) to line k = i - 16.
                // j will iterate pixels on that line.
                
                // We are in D_CHECK. The outer loop is 'i' (line index).
                // We need 'j' (pixel index on line) to be stable for checking.
                
                // Logic: 
                // Check diagonal i (calculated k = i - 16). 
                // Top-Left to Bottom-Right:
                // Valid range of pixels: max(0, k) to min(15, 15+k).
                // If we are here, we assume 'i' is the line index and 'j' is the pixel index.
                // But we need to check ALL pixels on line 'i' to set temp_valid.
                // So, temp_valid must be computed based on 'i' only.
                
                // Let's refine D_CHECK logic to compute validity for line 'i'.
                // Input 'i' (1..31) represents the line.
                // k = i - 16.
                // Top-Left Line:
                // Start row: max(0, k). End row: min(15, 15+k).
                // Pixels: r, c = r, r - k.
                
                // Bottom-Left to Top-Right (Anti-Diagonal):
                // Sum r + c = s. s from 0 to 30.
                // We need to interleave checks? 
                // Priority: Smallest (r1, c1). 
                // TL->BR lines have r1 >= 1, c1 >= 1 (mostly).
                // BL->TR lines have r1 > c1 usually? 
                // TL->BR (k=-15..15):
                //   k=15: (0,15) -> r1=1, c1=16
                //   k=0: (0,0) -> r1=1, c1=1
                //   k=-15: (15,0) -> r1=16, c1=1
                // BL->TR (s=0..30):
                //   s=0: (0,0) -> r1=1, c1=1
                //   s=1: (1,0) or (0,1)? 
                //   s=30: (15,15) -> r1=16, c1=16
                
                // Let's create a unified index.
                // We can check all 62 diagonal lines.
                // Use i (1 to 62) to index them.
                // 1-31: TL->BR. 32-62: BL->TR.
                
                if (i >= 1 && i <= 31) begin
                    // TL -> BR
                    // k = i - 16. 
                    // r1 = max(0, k) + 1. c1 = r1 - k.
                    // r2 = min(15, 15+k) + 1. c2 = r2 - k.
                    // Check validity.
                    temp_valid = 1;
                    // Determine pixel range
                    int start_r, end_r, k_val;
                    k_val = i - 16;
                    start_r = (k_val > 0) ? k_val : 0;
                    end_r = (k_val < 0) ? 15 + k_val : 15;
                    
                    if (start_r <= end_r) begin
                        // Set outputs for this line (using first pixel)
                        temp_r1 = start_r + 1;
                        temp_c1 = start_r - k_val + 1;
                        temp_r2 = end_r + 1;
                        temp_c2 = end_r - k_val + 1;
                        
                        // Check all pixels
                        for (int p = start_r; p <= end_r; p++) begin
                            int c_p;
                            c_p = p - k_val;
                            // Mirror: p_m = 15 - p, c_m = 15 - c_p
                            // Pair: (p, c_p) and (15-p, 15-c_p)
                            // Condition: (p, c_p) is Top-Left, (15-p, 15-c_p) is Bottom-Right.
                            // Rule: A(TL) = 1 is OK.
                            if (grid_row[p][c_p] != grid_row[15-p][15-c_p]) begin
                                if (grid_row[p][c_p] == 1'b0 && grid_row[15-p][15-c_p] == 1'b1) begin
                                    temp_valid = 0;
                                end
                            end
                        end
                    end else begin
                        temp_valid = 0; // Empty line (shouldn't happen with range)
                    end
                end else if (i >= 32 && i <= 62) begin
                    // BL -> TR
                    // s = i - 32.
                    // r1 = max(0, s-15) + 1. c1 = s - r1 + 1.
                    // r2 = min(15, s) + 1. c2 = s - r2 + 1.
                    temp_valid = 1;
                    int s_val, start_r, end_r;
                    s_val = i - 32;
                    start_r = (s_val > 15) ? s_val - 15 : 0;
                    end_r = (s_val < 15) ? s_val : 15;

                    if (start_r <= end_r) begin
                        temp_r1 = start_r + 1;
                        temp_c1 = s_val - start_r + 1;
                        temp_r2 = end_r + 1;
                        temp_c2 = s_val - end_r + 1;

                        for (int p = start_r; p <= end_r; p++) begin
                            int c_p;
                            c_p = s_val - p;
                            // Mirror: (p, c_p) vs (15-p, 15-c_p)
                            // Rule: A(TL?) -> Wait, fold is through (p,c_p) and (15-p, 15-c_p).
                            // Which one is A? The problem implies a fold line. 
                            // "A=1 (gold) is OK. B='.' and A='#' is OK, B='#' and A='.' is not".
                            // This usually refers to the seam where A is on one side, B on the other.
                            // Let's assume we map this logic to the diagonal pixels similarly.
                            // (p, c_p) is in the top-left quadrant? 
                            // Let's check (p, c_p) as A. If A is paper (0) and B is gold (1), invalid.
                            if (grid_row[p][c_p] != grid_row[15-p][15-c_p]) begin
                                if (grid_row[p][c_p] == 1'b0 && grid_row[15-p][15-c_p] == 1'b1) begin
                                    temp_valid = 0;
                                end
                            end
                        end
                    end else begin
                        temp_valid = 0;
                    end
                end
            end
        endcase
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            i <= 0;
            j <= 0;
            found <= 0;
            valid_int <= 0;
            // Reset outputs
            r1 <= 0; c1 <= 0; r2 <= 0; c2 <= 0;
            valid <= 0; done <= 0;
        end else begin
            current_state <= next_state;
            i <= next_i;
            j <= next_j;
            found <= next_found;
            valid_int <= next_valid_int;

            // Output update logic (synchronous)
            if (next_state == FOUND) begin
                // Capture the coordinates that were valid
                r1 <= temp_r1;
                c1 <= temp_c1;
                r2 <= temp_r2;
                c2 <= temp_c2;
                valid <= 1;
            end else if (next_state == DONE_STATE) begin
                done <= 1;
            end else begin
                // Clear done/valid when leaving done or starting new
                if (next_state == IDLE) begin
                    valid <= 0;
                    done <= 0;
                end
            end
        end
    end

    always @(*) begin
        next_state = current_state;
        next_i = i;
        next_j = j;
        next_found = found;
        next_valid_int = valid_int;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = H_CHECK;
                    next_i = 1; // Start at row 1 (logic row 0)
                    next_found = 0;
                    // Reset outputs
                end
            end

            H_CHECK: begin
                // Check row i
                if (temp_valid) begin
                    next_state = FOUND;
                end else begin
                    if (i < 15) begin
                        next_i = i + 1;
                    end else begin
                        next_i = 1;
                        next_state = V_CHECK;
                    end
                end
            end

            V_CHECK: begin
                // Check col i
                if (temp_valid) begin
                    next_state = FOUND;
                end else begin
                    if (i < 15) begin
                        next_i = i + 1;
                    end else begin
                        next_i = 1;
                        next_state = D_CHECK;
                    end
                end
            end

            D_CHECK: begin
                // Check diagonal i (1 to 62)
                if (temp_valid) begin
                    next_state = FOUND;
                end else begin
                    if (i < 62) begin
                        next_i = i + 1;
                    end else begin
                        // No valid fold found after exhaustive search
                        next_state = DONE_STATE;
                    end
                end
            end

            FOUND: begin
                // Found a valid fold. Stop searching.
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                // Stay here until reset or start
                if (start) begin
                    next_state = H_CHECK;
                    next_i = 1;
                    next_found = 0;
                    done = 0;
                    valid = 0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule