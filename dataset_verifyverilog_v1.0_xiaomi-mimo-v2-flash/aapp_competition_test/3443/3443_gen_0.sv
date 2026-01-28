module SpotSymmetry(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [12:0] pt_x [0:7],
    input wire [12:0] pt_y [0:7],
    input wire [3:0] len,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CALC_CENTROID = 4'd1;
    localparam [3:0] EVAL_POINT    = 4'd2;
    localparam [3:0] EVAL_VERT     = 4'd3;
    localparam [3:0] EVAL_HORIZ    = 4'd4;
    localparam [3:0] EVAL_DIAG_1   = 4'd5;
    localparam [3:0] EVAL_DIAG_2   = 4'd6;
    localparam [3:0] DONE_STATE    = 4'd7;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Cycle counter for safety
    reg [10:0] cycle_cnt;
    localparam [10:0] MAX_CYCLES = 11'd2000;

    // Inputs stored in registers
    reg [12:0] x_reg [0:7];
    reg [12:0] y_reg [0:7];
    reg [3:0] len_reg;

    // Intermediate results
    reg [4:0] min_additions;
    reg [4:0] current_additions;

    // Centroid calculation variables
    reg [27:0] sum_x;
    reg [27:0] sum_y;
    reg [12:0] centroid_x;
    reg [12:0] centroid_y;
    reg [3:0] i_cnt; // General purpose counter
    reg [3:0] j_cnt;
    reg [3:0] k_cnt;
    reg signed [25:0] diff_x;
    reg signed [25:0] diff_y;
    reg signed [13:0] temp_val;

    // Variables for sorting and pairing
    reg [12:0] sort_x [0:7];
    reg [12:0] sort_y [0:7];
    reg [12:0] mapped_val [0:7]; // (x-y) or (x+y)
    reg matched [0:7];
    reg [3:0] matched_count;
    reg found;

    // Input storage and main FSM
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            cycle_cnt <= 11'd0;
            min_additions <= 5'd8; // Start with max possible (all points added)
            
            // Initialize regs
            sum_x <= 28'd0;
            sum_y <= 28'd0;
            centroid_x <= 13'd0;
            centroid_y <= 13'd0;
            current_additions <= 5'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            k_cnt <= 4'd0;
            
            for (idx = 0; idx < 8; idx = idx + 1) begin
                x_reg[idx] <= 13'd0;
                y_reg[idx] <= 13'd0;
                sort_x[idx] <= 13'd0;
                sort_y[idx] <= 13'd0;
                mapped_val[idx] <= 13'd0;
                matched[idx] <= 1'b0;
            end

        end else begin
            // Default assignments
            done <= 1'b0;
            cycle_cnt <= cycle_cnt + 11'd1;

            case (state)
                IDLE: begin
                    cycle_cnt <= 11'd0;
                    min_additions <= 5'd8;
                    done <= 1'b0;
                    if (start) begin
                        // Store inputs
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (idx < len) begin
                                x_reg[idx] <= pt_x[idx];
                                y_reg[idx] <= pt_y[idx];
                            end else begin
                                x_reg[idx] <= 13'd0;
                                y_reg[idx] <= 13'd0;
                            end
                        end
                        len_reg <= len;
                        
                        // Reset counters
                        sum_x <= 28'd0;
                        sum_y <= 28'd0;
                        i_cnt <= 4'd0;
                        
                        state <= CALC_CENTROID;
                    end
                end

                CALC_CENTROID: begin
                    // Accumulate sums
                    if (i_cnt < len_reg) begin
                        sum_x <= sum_x + {{15{x_reg[i_cnt][12]}}, x_reg[i_cnt]};
                        sum_y <= sum_y + {{15{y_reg[i_cnt][12]}}, y_reg[i_cnt]};
                        i_cnt <= i_cnt + 4'd1;
                    end else begin
                        // Calculate division: Sum / len
                        // Result will be rounded down
                        if (len_reg > 4'd0) begin
                            centroid_x <= sum_x[27:15] / len_reg;
                            centroid_y <= sum_y[27:15] / len_reg;
                        end else begin
                            centroid_x <= 13'd0;
                            centroid_y <= 13'd0;
                        end
                        
                        i_cnt <= 4'd0;
                        state <= EVAL_POINT;
                    end
                end

                EVAL_POINT: begin
                    // Check point symmetry about centroid
                    // For each point (xi, yi), check if (2*cx - xi, 2*cy - yi) exists in set
                    // Mismatches count as additions needed. (Pairs -> 0 additions, single -> 1 addition)
                    // Result = Unmatched Points / 2
                    
                    if (i_cnt < len_reg) begin
                        if (matched[i_cnt]) begin
                            // Already paired, skip
                            i_cnt <= i_cnt + 4'd1;
                        end else begin
                            // Find partner
                            found <= 1'b0;
                            j_cnt <= 4'd0;
                            // Calculate partner coordinates: Cent*2 - P
                            // Using scaled arithmetic: P*2 is just P shifted
                            // diff = 2*C - X => ((C - X) + C)
                            // Let's do: target_x = (centroid_x << 1) - x_reg[i_cnt]
                            temp_val <= ( {centroid_x[12], centroid_x} << 1 ) - x_reg[i_cnt];
                            state <= EVAL_POINT + 4'd1; // Micro-state jump
                        end
                    end else begin
                        // Done checking points
                        current_additions <= (len_reg - matched_count) >> 1;
                        i_cnt <= 4'd0;
                        state <= EVAL_VERT;
                    end
                end

                4'd8: begin // Micro-state for searching partner in EVAL_POINT
                    if (j_cnt < len_reg) begin
                        if (j_cnt != i_cnt && !matched[j_cnt]) begin
                            // Check Y match
                            if ( ( ( {centroid_y[12], centroid_y} << 1 ) - y_reg[j_cnt] ) == y_reg[i_cnt] ) begin
                                // Check X match (already computed in temp_val)
                                if (x_reg[j_cnt] == temp_val[12:0]) begin
                                    matched[i_cnt] <= 1'b1;
                                    matched[j_cnt] <= 1'b1;
                                    matched_count <= matched_count + 4'd2;
                                    found <= 1'b1;
                                end
                            end
                        end
                        j_cnt <= j_cnt + 4'd1;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                        state <= EVAL_POINT;
                    end
                end

                EVAL_VERT: begin
                    // Sort by X (Bubble sort for 8 elements)
                    // Only sort valid points (len_reg)
                    // Initialize sort arrays
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            sort_x[idx] <= x_reg[idx];
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0; // Reuse matched for 'in line' flag
                        end
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        // Bubble sort pass
                        // j_cnt tracks inner loop
                        if (j_cnt < len_reg - i_cnt) begin
                            if (sort_x[j_cnt] > sort_x[j_cnt + 1]) begin
                                // Swap X
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                                // Swap Y with X
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        // Sorting done, calculate min additions for vertical line
                        // Line x = c. Min additions to make points collinear on vertical line?
                        // Actually, symmetry on vertical line means pairing points with same X reflection.
                        // x' = 2*c - x. For points on line x=c, x=c.
                        // If we enforce symmetry about x=c, we need pairs (x1, x2) such that x1+x2 = 2c.
                        // Min additions to achieve this? 
                        // Let's simplify problem to: Make all points symmetric w.r.t some line/point.
                        // Vert Line: x = c. 
                        // Points with same x can pair. Points with distinct x need partners.
                        // Strategy: Try every unique X coordinate in sorted array as the line 'c'.
                        // Additions = (points NOT on line x=c) / 2 (approx) + logic for pairing across.
                        // Better approach: 
                        // We need to add points such that for every point (x,y), (2c-x, y) exists.
                        // C is determined by averaging. 
                        // For vertical line x=c, C is constant.
                        // We iterate through unique X values in sorted list as candidates for c.
                        // Cost = (Total Points - Points On Line) / 2 + Points On Line (if odd count? No, symmetry center is line)
                        // Actually, if we pick line x=c, points ON line are self-symmetric? No, they stay.
                        // Points OFF line must have partners. 
                        // Cost = number of unpaired off-line points / 2.
                        // Wait, if 1 point is off line, we add 1 point. 
                        // If 2 points are at x1 and x2 (x1!=c, x2!=c), they can pair if x1+x2 = 2c. 
                        // 
                        // Let's stick to the heuristic: 
                        // Iterate potential centers c.
                        // Count how many points already satisfy symmetry.
                        // Unmatched = Total - Matched. Additions = Unmatched / 2.
                        
                        // Reset for iteration
                        i_cnt <= 4'd0; // Candidate index
                        state <= 4'd9; // Micro-state for VERT iteration
                    end
                end

                4'd9: begin // VERT: Iterate candidates
                    if (i_cnt < len_reg) begin
                        // Candidate center x = sort_x[i_cnt]
                        // Clear matched flags
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        
                        j_cnt <= 4'd0; // Point 1
                        k_cnt <= 4'd0; // Point 2
                        matched_count <= 4'd0;
                        state <= 4'd10;
                    end else begin
                        // Done with all candidates, move to next symmetry type
                        current_additions <= min_additions; // Update current result
                        min_additions <= 5'd8; // Reset for HORIZ
                        i_cnt <= 4'd0;
                        state <= EVAL_HORIZ;
                    end
                end

                4'd10: begin // VERT: Check pairs for candidate i_cnt
                    // Loop structure: Find pairs (j, k) such that x_j + x_k = 2 * x_c
                    // and y_j == y_k (Horizontal symmetry is default for vertical line)
                    // Wait, vertical line symmetry x=c: P(x,y) <-> P'(2c-x, y).
                    // We need y to match.
                    // 
                    // Optimization: Since N is small (8), we can just count valid pairs.
                    // A point is 'paired' if its partner exists.
                    // Unpaired points require additions.
                    
                    // Let's simplify: Iterate all points. If not matched, look for partner.
                    // If found, mark matched. If not, count as unmatched.
                    
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            // Look for partner for j_cnt
                            // Partner x: 2*c - x_j
                            // Partner y: y_j
                            temp_val <= ( {sort_x[i_cnt][12], sort_x[i_cnt]} << 1 ) - sort_x[j_cnt];
                            k_cnt <= 4'd0;
                            state <= 4'd11;
                        end
                    end else begin
                        // All points processed for this candidate
                        // Additions needed = (len_reg - matched_count) / 2
                        // Because each unmatched point needs a partner added.
                        // If 1 point unmatched, we add 1. 
                        // Wait, if we have 1 point P, we add P'. Total points become 2. Additions = 1.
                        // If we have 2 points P1, P2 (not symmetric), we might add P1', P2'. Additions = 2.
                        // But we can add fewer if they pair up?
                        // If P1 and P2 are symmetric w.r.t c, Additions = 0.
                        // If P1 matches P2 (P2 is partner of P1), then 0.
                        // If P1 has no partner, Additions += 1.
                        // 
                        // Formula: Additions = Unmatched Points.
                        // Because every unmatched point requires a partner to be added.
                        
                        temp_val <= len_reg - matched_count; // temp_val used as int storage
                        // Update min_additions if better
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd9;
                    end
                end

                4'd11: begin // VERT: Search partner for j_cnt
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            // Check Y match
                            if (sort_y[k_cnt] == sort_y[j_cnt]) begin
                                // Check X match
                                if (sort_x[k_cnt] == temp_val[12:0]) begin
                                    matched[j_cnt] <= 1'b1;
                                    matched[k_cnt] <= 1'b1;
                                    matched_count <= matched_count + 4'd2;
                                    // Jump out of search loop
                                    k_cnt <= len_reg; // Force exit
                                end
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        // No partner found or found
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd10;
                    end
                end

                EVAL_HORIZ: begin
                    // Sort by Y
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            sort_x[idx] <= x_reg[idx];
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0;
                        end
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        if (j_cnt < len_reg - i_cnt) begin
                            if (sort_y[j_cnt] > sort_y[j_cnt + 1]) begin
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        state <= 4'd12; // Iterate HORIZ candidates
                    end
                end

                4'd12: begin // HORIZ: Iterate candidates (Y values)
                    if (i_cnt < len_reg) begin
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        j_cnt <= 4'd0;
                        matched_count <= 4'd0;
                        state <= 4'd13;
                    end else begin
                        // Update min
                        if (min_additions > current_additions) begin
                            min_additions <= current_additions;
                        end
                        current_additions <= 5'd8;
                        i_cnt <= 4'd0;
                        state <= EVAL_DIAG_1;
                    end
                end

                4'd13: begin // HORIZ: Check pairs
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            // Partner y: 2*c - y_j, x: x_j
                            temp_val <= ( {sort_y[i_cnt][12], sort_y[i_cnt]} << 1 ) - sort_y[j_cnt];
                            k_cnt <= 4'd0;
                            state <= 4'd14;
                        end
                    end else begin
                        temp_val <= len_reg - matched_count;
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd12;
                    end
                end

                4'd14: begin // HORIZ: Search partner
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            if (sort_x[k_cnt] == sort_x[j_cnt]) begin
                                if (sort_y[k_cnt] == temp_val[12:0]) begin
                                    matched[j_cnt] <= 1'b1;
                                    matched[k_cnt] <= 1'b1;
                                    matched_count <= matched_count + 4'd2;
                                    k_cnt <= len_reg;
                                end
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd13;
                    end
                end

                EVAL_DIAG_1: begin
                    // Diagonal x = y + c => x - y = c
                    // Map values: val = x - y
                    // Sort by val
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < len_reg; idx = idx + 1) begin
                            mapped_val[idx] <= x_reg[idx] - y_reg[idx];
                            sort_x[idx] <= x_reg[idx]; // Keep original coords
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0;
                        end
                        for (idx = len_reg; idx < 8; idx = idx + 1) begin
                            mapped_val[idx] <= 13'd0;
                            matched[idx] <= 1'b0;
                        end
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        if (j_cnt < len_reg - i_cnt) begin
                            if (mapped_val[j_cnt] > mapped_val[j_cnt + 1]) begin
                                // Swap mapped_val
                                mapped_val[j_cnt] <= mapped_val[j_cnt + 1];
                                mapped_val[j_cnt + 1] <= mapped_val[j_cnt];
                                // Swap coords
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        state <= 4'd15;
                    end
                end

                4'd15: begin // DIAG1: Iterate candidates
                    if (i_cnt < len_reg) begin
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        j_cnt <= 4'd0;
                        matched_count <= 4'd0;
                        state <= 4'd16;
                    end else begin
                        if (min_additions > current_additions) begin
                            min_additions <= current_additions;
                        end
                        current_additions <= 5'd8;
                        i_cnt <= 4'd0;
                        state <= EVAL_DIAG_2;
                    end
                end

                4'd16: begin // DIAG1: Check pairs
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            // c = mapped_val[i]
                            // Partner val = 2*c - val_j
                            // Partner x = y + c => x = y + c => y = x - c
                            // But we are pairing based on (x-y) values.
                            // If two points have same (x-y), they are on the line? No.
                            // Symmetry on x=y+c: Point P(x,y) <-> P'(x', y') such that x'-y' = x-y = c.
                            // AND P' is reflection of P. 
                            // Reflection formula for x=y+c: 
                            // x' = y + c, y' = x - c.
                            // Wait, if c is fixed, P'(y+c, x-c).
                            // We need to check if P' exists in the set.
                            // Condition: For point P1(x1, y1) and P2(x2, y2):
                            // x1 - y1 == x2 - y2 (same c)
                            // AND x2 == y1 + c, y2 == x1 - c.
                            // Simplification: x1 + y1 == x2 + y2.
                            // 
                            // So for a candidate c (defined by point i_cnt):
                            // We look for partners j (j != i_cnt) such that:
                            // 1. x_j - y_j == x_i - y_i (Same line candidate)
                            // 2. x_j + y_j == x_i + y_i (Symmetry condition)
                            // 
                            // Optimization: Precompute x+y.
                            // Let's just use the search loop.
                            temp_val <= ( {mapped_val[i_cnt][12], mapped_val[i_cnt]} << 1 ) - mapped_val[j_cnt]; // Target mapped val
                            // Target x+y? 
                            // x_p + y_p = x_j + y_j. 
                            // We need to find P' such that mapped(P') = mapped(P).
                            // AND x_p' + y_p' = x_p + y_p.
                            // Wait, if mapped(P') = mapped(P), then x_p' - y_p' = x_p - y_p.
                            // If also x_p' + y_p' = x_p + y_p, then adding: 2x_p' = 2x_p => x_p' = x_p, y_p' = y_p.
                            // That's the same point. 
                            // 
                            // Let's re-read symmetry for x=y+c.
                            // If P is on the line, it stays.
                            // If P is off line, P' is the reflection.
                            // If P is at (x,y), P' is at (y+c, x-c).
                            // Does P' lie on x=y+c? (y+c) = (x-c) + c = x. Yes.
                            // 
                            // Check if P' exists:
                            // We need to find index k such that:
                            // x_k = y_j + c
                            // y_k = x_j - c
                            // where c = x_i - y_i (i_cnt is candidate).
                            
                            // Calculate target coords
                            // x_target = y_j + (x_i - y_i)
                            // y_target = x_j - (x_i - y_i)
                            // Store in temp_val and k_cnt (reused as storage)
                            // 
                            // Use diff_x for x_target, diff_y for y_target
                            diff_x <= y_reg[j_cnt] + mapped_val[i_cnt];
                            diff_y <= x_reg[j_cnt] - mapped_val[i_cnt];
                            k_cnt <= 4'd0;
                            state <= 4'd17;
                        end
                    end else begin
                        temp_val <= len_reg - matched_count;
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd15;
                    end
                end

                4'd17: begin // DIAG1: Search partner k
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            if (sort_x[k_cnt] == diff_x[12:0] && sort_y[k_cnt] == diff_y[12:0]) begin
                                // Check mapped value match too (consistency)
                                if (mapped_val[k_cnt] == mapped_val[i_cnt]) begin
                                    matched[j_cnt] <= 1'b1;
                                    matched[k_cnt] <= 1'b1;
                                    matched_count <= matched_count + 4'd2;
                                    k_cnt <= len_reg;
                                end
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd16;
                    end
                end

                EVAL_DIAG_2: begin
                    // Diagonal x = -y + c => x + y = c
                    // Map values: val = x + y
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < len_reg; idx = idx + 1) begin
                            mapped_val[idx] <= x_reg[idx] + y_reg[idx];
                            sort_x[idx] <= x_reg[idx];
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0;
                        end
                        for (idx = len_reg; idx < 8; idx = idx + 1) begin
                            mapped_val[idx] <= 13'd0;
                            matched[idx] <= 1'b0;
                        end
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        if (j_cnt < len_reg - i_cnt) begin
                            if (mapped_val[j_cnt] > mapped_val[j_cnt + 1]) begin
                                mapped_val[j_cnt] <= mapped_val[j_cnt + 1];
                                mapped_val[j_cnt + 1] <= mapped_val[j_cnt];
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        state <= 4'd18;
                    end
                end

                4'd18: begin // DIAG2: Iterate candidates
                    if (i_cnt < len_reg) begin
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        j_cnt <= 4'd0;
                        matched_count <= 4'd0;
                        state <= 4'd19;
                    end else begin
                        if (min_additions > current_additions) begin
                            min_additions <= current_additions;
                        end
                        // Point symmetry already calculated? 
                        // Yes, but let's include it in min calc properly.
                        // Actually, Point Symmetry result was stored in 'current_additions' before EVAL_VERT.
                        // But min_additions was reset to 8 before VERT.
                        // Wait, I lost the Point Symmetry result in EVAL_POINT->EVAL_VERT transition.
                        // In EVAL_POINT, I did: current_additions <= (len_reg - matched_count) >> 1;
                        // Then state <= EVAL_VERT. 
                        // Then in EVAL_VERT start, I didn't compare with min_additions.
                        // Fix: Compare current_additions with min_additions before EVAL_VERT.
                        // Since we are here, let's just set result.
                        
                        state <= DONE_STATE;
                    end
                end

                4'd19: begin // DIAG2: Check pairs
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            // Symmetry x = -y + c => x + y = c.
                            // Reflection: x' = -y + c, y' = -x + c.
                            // Or: x' + y' = c.
                            // Target: x' = -y + (x+y) = x
                            // Target: y' = -x + (x+y) = y
                            // Wait, that's wrong.
                            // Formula for reflection across x + y = c:
                            // x' = c - y = (x+y) - y = x (??? No)
                            // 
                            // Let's derive.
                            // Line L: x + y = c.
                            // P(x, y). P' is reflection.
                            // Vector normal is (1, 1). 
                            // P' = P - 2 * dist_to_line * normal_unit.
                            // 
                            // Simpler geometric constraint for P' on line x+y=c:
                            // 1. P' is on line: x' + y' = c.
                            // 2. Midpoint of P and P' is on line: (x+x')/2 + (y+y')/2 = c.
                            //    x + x' + y + y' = 2c => (x+y) + (x'+y') = 2c.
                            //    Since x+y = c and x'+y' = c, c + c = 2c. (Consistent)
                            // 3. Segment PP' is perpendicular to line (slope -1). Slope of PP' is 1.
                            //    (y' - y) / (x' - x) = 1 => y' - y = x' - x => x' - y' = x - y.
                            // 
                            // Conditions for P'(x', y') to be partner of P(x, y) wrt line x+y=c:
                            // x' + y' = c  (Same c)
                            // x' - y' = x - y
                            // 
                            // Solving:
                            // 2x' = c + (x-y) => x' = (c + x - y) / 2
                            // 2y' = c - (x-y) => y' = (c - x + y) / 2
                            // 
                            // With c = x_i + y_i (candidate center):
                            // x' = (x_i + y_i + x_j - y_j) / 2
                            // y' = (x_i + y_i - x_j + y_j) / 2
                            
                            // Since inputs are integers, sums might be odd. 
                            // If result is not integer, partner doesn't exist.
                            
                            // Calculate target
                            // Use diff_x and diff_y for intermediates
                            diff_x <= mapped_val[i_cnt] + x_reg[j_cnt] - y_reg[j_cnt]; // 2 * x'
                            diff_y <= mapped_val[i_cnt] - x_reg[j_cnt] + y_reg[j_cnt]; // 2 * y'
                            k_cnt <= 4'd0;
                            state <= 4'd20;
                        end
                    end else begin
                        temp_val <= len_reg - matched_count;
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd18;
                    end
                end

                4'd20: begin // DIAG2: Search partner k
                    // Check if diff_x and diff_y are even, then divide by 2
                    if (diff_x[0] == 1'b0 && diff_y[0] == 1'b0) begin
                        diff_x <= diff_x >>> 1;
                        diff_y <= diff_y >>> 1;
                        k_cnt <= 4'd0;
                        state <= 4'd21;
                    end else begin
                        // Not integer coordinates, no match
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd19;
                    end
                end

                4'd21: begin // DIAG2: Verify match
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            if (sort_x[k_cnt] == diff_x[12:0] && sort_y[k_cnt] == diff_y[12:0]) begin
                                // Check c consistency
                                if (mapped_val[k_cnt] == mapped_val[i_cnt]) begin
                                    matched[j_cnt] <= 1'b1;
                                    matched[k_cnt] <= 1'b1;
                                    matched_count <= matched_count + 4'd2;
                                    k_cnt <= len_reg;
                                end
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd19;
                    end
                end

                DONE_STATE: begin
                    // Point symmetry result is lost? Let's recalculate or trust min_additions.
                    // In EVAL_POINT, we calculated additions for point symmetry.
                    // But we didn't compare it with min_additions before resetting.
                    // Wait, in EVAL_POINT exit: current_additions <= (len_reg - matched_count) >> 1;
                    // Then state <= EVAL_VERT.
                    // In EVAL_VERT, we reset min_additions to 8? No, we kept min_additions from IDLE (8).
                    // We should have updated min_additions if point symmetry was better.
                    // But we skipped that. 
                    // To fix: We can just include Point Symmetry logic here? 
                    // No, we already processed the points in EVAL_POINT.
                    // The 'current_additions' after EVAL_POINT holds point symmetry cost.
                    // Then in EVAL_VERT, we started calculating min_additions for VERT.
                    // At the end of VERT, we compared VERT cost with min_additions.
                    // But min_additions was still 8 (initial value).
                    // So we lost the Point Symmetry result unless we update min_additions in EVAL_POINT.
                    // 
                    // Let's assume we want the global minimum.
                    // We need to handle Point Symmetry result.
                    // Since we can't go back, we can re-run point symmetry check quickly? No, too late.
                    // Actually, looking at the flow:
                    // IDLE -> CALC_CENTROID -> EVAL_POINT -> EVAL_VERT.
                    // In EVAL_POINT exit: current_additions = PointCost.
                    // In EVAL_VERT start: min_additions is still 8.
                    // We should have: if (PointCost < min_additions) min = PointCost.
                    // Since we didn't, and min_additions tracks the BEST of the remaining checks (Vert, Horiz, Diag1, Diag2).
                    // The final answer is min(min_additions, PointCost).
                    // We have min_additions (best of last 4 types).
                    // We need PointCost. 
                    // We can store PointCost in a dedicated register 'point_cost' and use it here.
                    // Let's declare point_cost.
                    // In EVAL_POINT exit: point_cost <= (len_reg - matched_count) >> 1;
                    // 
                    // Update code to include point_cost register.
                    
                    if (min_additions > point_cost) begin
                        result <= point_cost;
                    end else begin
                        result <= min_additions;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Register to hold point symmetry cost
    reg [4:0] point_cost;
    
    // Update point_cost in EVAL_POINT state logic
    // We need to modify the EVAL_POINT block in the always block above to assign to point_cost.
    // However, since I cannot edit the generated block string directly without rewriting:
    // I will assume the logic in EVAL_POINT (state 4'd8) eventually sets a value.
    // I will add a continuous assignment or modify the logic block.
    // Actually, I can add a separate always block or logic.
    // But the prompt says 'single always block' for FSM usually.
    // Let's put the point_cost assignment inside EVAL_POINT's completion condition.
    // 
    // Wait, the code in EVAL_POINT (state 4'd8) logic is:
    // if (i_cnt < len_reg) ...
    // else begin current_additions <= ... state <= EVAL_VERT; end
    // 
    // To fix the lost variable issue without adding a new register in the FSM (which requires careful handling):
    // I will inject the `point_cost` logic into the JSON code block.
    // Actually, I can define `point_cost` and update it in the `EVAL_POINT` else block.

endmodule

// Note: The above module uses a complex FSM. 
// To ensure 'point_cost' is handled correctly:
// I will redefine the module with the fix integrated.

module SpotSymmetry_Fixed(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [12:0] pt_x [0:7],
    input wire [12:0] pt_y [0:7],
    input wire [3:0] len,
    output reg [4:0] result,
    output reg done
);

    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CALC_CENTROID = 4'd1;
    localparam [3:0] EVAL_POINT    = 4'd2;
    localparam [3:0] EVAL_VERT     = 4'd3;
    localparam [3:0] EVAL_HORIZ    = 4'd4;
    localparam [3:0] EVAL_DIAG_1   = 4'd5;
    localparam [3:0] EVAL_DIAG_2   = 4'd6;
    localparam [3:0] DONE_STATE    = 4'd7;

    reg [3:0] state;
    reg [10:0] cycle_cnt;

    reg [12:0] x_reg [0:7];
    reg [12:0] y_reg [0:7];
    reg [3:0] len_reg;

    reg [4:0] min_additions;
    reg [4:0] point_cost_reg;

    // Centroid
    reg [27:0] sum_x;
    reg [27:0] sum_y;
    reg [12:0] centroid_x;
    reg [12:0] centroid_y;
    
    // Counters
    reg [3:0] i_cnt;
    reg [3:0] j_cnt;
    reg [3:0] k_cnt;
    reg [4:0] matched_count;
    
    // Temp values
    reg signed [13:0] temp_val;
    reg signed [25:0] diff_x;
    reg signed [25:0] diff_y;
    
    // Arrays
    reg [12:0] sort_x [0:7];
    reg [12:0] sort_y [0:7];
    reg [12:0] mapped_val [0:7];
    reg matched [0:7];
    
    // Flags
    reg found;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            cycle_cnt <= 11'd0;
            min_additions <= 5'd8;
            point_cost_reg <= 5'd8;
            sum_x <= 28'd0;
            sum_y <= 28'd0;
            centroid_x <= 13'd0;
            centroid_y <= 13'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            k_cnt <= 4'd0;
            matched_count <= 5'd0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                x_reg[idx] <= 13'd0;
                y_reg[idx] <= 13'd0;
                sort_x[idx] <= 13'd0;
                sort_y[idx] <= 13'd0;
                mapped_val[idx] <= 13'd0;
                matched[idx] <= 1'b0;
            end
        end else begin
            done <= 1'b0;
            cycle_cnt <= cycle_cnt + 11'd1;

            case (state)
                IDLE: begin
                    cycle_cnt <= 11'd0;
                    min_additions <= 5'd8;
                    point_cost_reg <= 5'd8;
                    if (start) begin
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (idx < len) begin
                                x_reg[idx] <= pt_x[idx];
                                y_reg[idx] <= pt_y[idx];
                            end else begin
                                x_reg[idx] <= 13'd0;
                                y_reg[idx] <= 13'd0;
                            end
                        end
                        len_reg <= len;
                        sum_x <= 28'd0;
                        sum_y <= 28'd0;
                        i_cnt <= 4'd0;
                        state <= CALC_CENTROID;
                    end
                end

                CALC_CENTROID: begin
                    if (i_cnt < len_reg) begin
                        sum_x <= sum_x + {{15{x_reg[i_cnt][12]}}, x_reg[i_cnt]};
                        sum_y <= sum_y + {{15{y_reg[i_cnt][12]}}, y_reg[i_cnt]};
                        i_cnt <= i_cnt + 4'd1;
                    end else begin
                        if (len_reg > 4'd0) begin
                            centroid_x <= sum_x[27:15] / len_reg;
                            centroid_y <= sum_y[27:15] / len_reg;
                        end else begin
                            centroid_x <= 13'd0;
                            centroid_y <= 13'd0;
                        end
                        i_cnt <= 4'd0;
                        matched_count <= 5'd0;
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        state <= EVAL_POINT;
                    end
                end

                EVAL_POINT: begin
                    // Check Point Symmetry
                    if (i_cnt < len_reg) begin
                        if (matched[i_cnt]) begin
                            i_cnt <= i_cnt + 4'd1;
                        end else begin
                            found <= 1'b0;
                            j_cnt <= 4'd0;
                            // Target x: 2*Cx - X
                            temp_val <= ( {centroid_x[12], centroid_x} << 1 ) - x_reg[i_cnt];
                            state <= 4'd8; // Micro-state
                        end
                    end else begin
                        // Point symmetry cost: Unmatched points count
                        // If matched_count is even, remaining are even? No.
                        // Total points - Matched points = Unmatched.
                        // Each unmatched point needs a partner added.
                        // Result is Unmatched count.
                        // Wait, if 1 point unmatched, add 1. If 2 unmatched, add 2 (unless they pair, but we are at centroid symmetry).
                        // Actually, for point symmetry, cost = (len_reg - matched_count).
                        point_cost_reg <= len_reg - matched_count;
                        i_cnt <= 4'd0;
                        state <= EVAL_VERT;
                    end
                end

                4'd8: begin // Point Sym: Find partner
                    if (j_cnt < len_reg) begin
                        if (j_cnt != i_cnt && !matched[j_cnt]) begin
                            if ( ( {centroid_y[12], centroid_y} << 1 ) - y_reg[j_cnt] == y_reg[i_cnt] ) begin
                                if (x_reg[j_cnt] == temp_val[12:0]) begin
                                    matched[i_cnt] <= 1'b1;
                                    matched[j_cnt] <= 1'b1;
                                    matched_count <= matched_count + 5'd2;
                                    found <= 1'b1;
                                end
                            end
                        end
                        j_cnt <= j_cnt + 4'd1;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                        state <= EVAL_POINT;
                    end
                end

                EVAL_VERT: begin
                    // Bubble Sort by X
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            sort_x[idx] <= x_reg[idx];
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0;
                        end
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        if (j_cnt < len_reg - i_cnt) begin
                            if (sort_x[j_cnt] > sort_x[j_cnt + 1]) begin
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        state <= 4'd9;
                    end
                end

                4'd9: begin // VERT: Iterate candidates
                    if (i_cnt < len_reg) begin
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        j_cnt <= 4'd0;
                        matched_count <= 5'd0;
                        state <= 4'd10;
                    end else begin
                        // Update min_additions with VERT result
                        // (min_additions was tracking the best so far)
                        // We need to ensure we keep the best of (Point, Vert, Horiz, etc)
                        // In IDLE, min_additions = 8.
                        // In EVAL_POINT exit, we stored cost in point_cost_reg.
                        // Here, we have a new cost (len_reg - matched_count) for VERT candidate.
                        // We need to compare this VERT cost with min_additions.
                        // But we also need to keep Point Cost in mind.
                        // So, before starting VERT, we should set min_additions = point_cost_reg.
                        // Let's do that at the start of VERT block.
                        
                        // Actually, let's just do the final comparison in DONE_STATE using all candidates.
                        // We will store VERT best in min_additions (which was initially 8).
                        // We will store Point best in point_cost_reg.
                        
                        // Transition to HORIZ
                        i_cnt <= 4'd0;
                        state <= EVAL_HORIZ;
                    end
                end

                4'd10: begin // VERT: Check pairs
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            temp_val <= ( {sort_x[i_cnt][12], sort_x[i_cnt]} << 1 ) - sort_x[j_cnt];
                            k_cnt <= 4'd0;
                            state <= 4'd11;
                        end
                    end else begin
                        // Cost for this candidate i_cnt
                        // Cost = Unmatched Points (because each unmatched needs a partner added)
                        // But if we have P1, P2, P3... and we add partners P1', P2', P3'...
                        // If 1 point unmatched, we add 1. 
                        // If 2 points unmatched, we add 2 (unless they pair, but if they didn't pair in loop, they don't)
                        // So Cost = len_reg - matched_count.
                        
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd9;
                    end
                end

                4'd11: begin // VERT: Search partner
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            if (sort_y[k_cnt] == sort_y[j_cnt] && sort_x[k_cnt] == temp_val[12:0]) begin
                                matched[j_cnt] <= 1'b1;
                                matched[k_cnt] <= 1'b1;
                                matched_count <= matched_count + 5'd2;
                                k_cnt <= len_reg;
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd10;
                    end
                end

                EVAL_HORIZ: begin
                    // Sort by Y
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            sort_x[idx] <= x_reg[idx];
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0;
                        end
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        if (j_cnt < len_reg - i_cnt) begin
                            if (sort_y[j_cnt] > sort_y[j_cnt + 1]) begin
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        state <= 4'd12;
                    end
                end

                4'd12: begin // HORIZ: Iterate
                    if (i_cnt < len_reg) begin
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        j_cnt <= 4'd0;
                        matched_count <= 5'd0;
                        state <= 4'd13;
                    end else begin
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= 4'd0;
                        state <= EVAL_DIAG_1;
                    end
                end

                4'd13: begin // HORIZ: Check pairs
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            temp_val <= ( {sort_y[i_cnt][12], sort_y[i_cnt]} << 1 ) - sort_y[j_cnt];
                            k_cnt <= 4'd0;
                            state <= 4'd14;
                        end
                    end else begin
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd12;
                    end
                end

                4'd14: begin // HORIZ: Search partner
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            if (sort_x[k_cnt] == sort_x[j_cnt] && sort_y[k_cnt] == temp_val[12:0]) begin
                                matched[j_cnt] <= 1'b1;
                                matched[k_cnt] <= 1'b1;
                                matched_count <= matched_count + 5'd2;
                                k_cnt <= len_reg;
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd13;
                    end
                end

                EVAL_DIAG_1: begin
                    // Map x-y, Sort
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < len_reg; idx = idx + 1) begin
                            mapped_val[idx] <= x_reg[idx] - y_reg[idx];
                            sort_x[idx] <= x_reg[idx];
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0;
                        end
                        for (idx = len_reg; idx < 8; idx = idx + 1) mapped_val[idx] <= 13'd0;
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        if (j_cnt < len_reg - i_cnt) begin
                            if (mapped_val[j_cnt] > mapped_val[j_cnt + 1]) begin
                                mapped_val[j_cnt] <= mapped_val[j_cnt + 1];
                                mapped_val[j_cnt + 1] <= mapped_val[j_cnt];
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        state <= 4'd15;
                    end
                end

                4'd15: begin // DIAG1: Iterate
                    if (i_cnt < len_reg) begin
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        j_cnt <= 4'd0;
                        matched_count <= 5'd0;
                        state <= 4'd16;
                    end else begin
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= 4'd0;
                        state <= EVAL_DIAG_2;
                    end
                end

                4'd16: begin // DIAG1: Check pairs
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            // Partner: x' = y + c, y' = x - c (c = x-y)
                            // x' = y + (x-y) = x
                            // y' = x - (x-y) = y
                            // Wait, that's wrong for x=y+c symmetry.
                            // Symmetry on x=y+c: 
                            // P(x,y) -> P'(x', y') 
                            // x' + y' = x + y ? No. 
                            // x' - y' = x - y (constraint on line)
                            // Midpoint on line: (x+x')/2 + (y+y')/2 = x-y ? No.
                            // 
                            // Correct derivation:
                            // Line: x - y = c.
                            // P(x,y), P'(x',y')
                            // 1. x' - y' = c = x - y.
                            // 2. Midpoint ( (x+x')/2, (y+y')/2 ) on line?
                            //    (x+x')/2 - (y+y')/2 = c
                            //    (x - y) + (x' - y') = 2c => c + c = 2c. (OK)
                            // 3. Perpendicular: Slope of line is 1. Slope of PP' is -1.
                            //    (y' - y) / (x' - x) = -1 => y' - y = -x' + x => x' + y' = x + y.
                            // 
                            // Conditions:
                            // x' - y' = x - y  (Same mapped value)
                            // x' + y' = x + y  (Sum constraint)
                            // 
                            // Solve:
                            // 2x' = (x-y) + (x+y) = 2x => x' = x
                            // 2y' = (x+y) - (x-y) = 2y => y' = y
                            // 
                            // Wait, this implies P' = P. That means P is on the line or something is wrong.
                            // Ah, reflection across x-y=c.
                            // If P is on line, P' = P.
                            // If P is off line, P' is distinct.
                            // 
                            // Let's use standard reflection matrix or geometric shift.
                            // Reflect P(x,y) across x - y = c.
                            // Let u = x - y - c. P is at distance |u|/sqrt(2) from line.
                            // Normal vector is (1, -1).
                            // P' = P - 2 * u * (1, -1) / (1^2 + (-1)^2)
                            // P' = (x, y) - (x-y-c) * (1, -1)
                            // x' = x - (x-y-c) = y + c
                            // y' = y + (x-y-c) = x - c
                            // 
                            // So P'(y+c, x-c).
                            // Note: c = x_i - y_i (candidate value).
                            // We need to find P' in the set.
                            // 
                            // For candidate c, we look for P(k) such that:
                            // x_k = y_j + c
                            // y_k = x_j - c
                            // 
                            // Calculate targets:
                            // x_target = y_j + (x_i - y_i)
                            // y_target = x_j - (x_i - y_i)
                            
                            diff_x <= y_reg[j_cnt] + mapped_val[i_cnt];
                            diff_y <= x_reg[j_cnt] - mapped_val[i_cnt];
                            k_cnt <= 4'd0;
                            state <= 4'd17;
                        end
                    end else begin
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd15;
                    end
                end

                4'd17: begin // DIAG1: Search partner
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            if (sort_x[k_cnt] == diff_x[12:0] && sort_y[k_cnt] == diff_y[12:0]) begin
                                // Check c consistency (mapped_val)
                                if (mapped_val[k_cnt] == mapped_val[i_cnt]) begin
                                    matched[j_cnt] <= 1'b1;
                                    matched[k_cnt] <= 1'b1;
                                    matched_count <= matched_count + 5'd2;
                                    k_cnt <= len_reg;
                                end
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd16;
                    end
                end

                EVAL_DIAG_2: begin
                    // Map x+y, Sort
                    if (i_cnt == 4'd0) begin
                        for (idx = 0; idx < len_reg; idx = idx + 1) begin
                            mapped_val[idx] <= x_reg[idx] + y_reg[idx];
                            sort_x[idx] <= x_reg[idx];
                            sort_y[idx] <= y_reg[idx];
                            matched[idx] <= 1'b0;
                        end
                        for (idx = len_reg; idx < 8; idx = idx + 1) mapped_val[idx] <= 13'd0;
                        i_cnt <= 4'd1;
                    end else if (i_cnt <= len_reg) begin
                        if (j_cnt < len_reg - i_cnt) begin
                            if (mapped_val[j_cnt] > mapped_val[j_cnt + 1]) begin
                                mapped_val[j_cnt] <= mapped_val[j_cnt + 1];
                                mapped_val[j_cnt + 1] <= mapped_val[j_cnt];
                                sort_x[j_cnt] <= sort_x[j_cnt + 1];
                                sort_x[j_cnt + 1] <= sort_x[j_cnt];
                                sort_y[j_cnt] <= sort_y[j_cnt + 1];
                                sort_y[j_cnt + 1] <= sort_y[j_cnt];
                            end
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            j_cnt <= 4'd0;
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        i_cnt <= 4'd0;
                        state <= 4'd18;
                    end
                end

                4'd18: begin // DIAG2: Iterate
                    if (i_cnt < len_reg) begin
                        for (idx = 0; idx < 8; idx = idx + 1) matched[idx] <= 1'b0;
                        j_cnt <= 4'd0;
                        matched_count <= 5'd0;
                        state <= 4'd19;
                    end else begin
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        state <= DONE_STATE;
                    end
                end

                4'd19: begin // DIAG2: Check pairs
                    if (j_cnt < len_reg) begin
                        if (matched[j_cnt]) begin
                            j_cnt <= j_cnt + 4'd1;
                        end else begin
                            // Line: x = -y + c => x + y = c
                            // Reflection P(x,y) -> P'(x', y')
                            // x' + y' = c
                            // x' - y' = x - y
                            // x' = (c + x - y) / 2
                            // y' = (c - x + y) / 2
                            
                            diff_x <= mapped_val[i_cnt] + x_reg[j_cnt] - y_reg[j_cnt];
                            diff_y <= mapped_val[i_cnt] - x_reg[j_cnt] + y_reg[j_cnt];
                            k_cnt <= 4'd0;
                            state <= 4'd20;
                        end
                    end else begin
                        if ( (len_reg - matched_count) < min_additions ) begin
                            min_additions <= len_reg - matched_count;
                        end
                        i_cnt <= i_cnt + 4'd1;
                        state <= 4'd18;
                    end
                end

                4'd20: begin // DIAG2: Check even
                    if (diff_x[0] == 1'b0 && diff_y[0] == 1'b0) begin
                        diff_x <= diff_x >>> 1;
                        diff_y <= diff_y >>> 1;
                        k_cnt <= 4'd0;
                        state <= 4'd21;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd19;
                    end
                end

                4'd21: begin // DIAG2: Search partner
                    if (k_cnt < len_reg) begin
                        if (k_cnt != j_cnt && !matched[k_cnt]) begin
                            if (sort_x[k_cnt] == diff_x[12:0] && sort_y[k_cnt] == diff_y[12:0]) begin
                                if (mapped_val[k_cnt] == mapped_val[i_cnt]) begin
                                    matched[j_cnt] <= 1'b1;
                                    matched[k_cnt] <= 1'b1;
                                    matched_count <= matched_count + 5'd2;
                                    k_cnt <= len_reg;
                                end
                            end
                        end
                        k_cnt <= k_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                        state <= 4'd19;
                    end
                end

                DONE_STATE: begin
                    // Compare Point Cost (point_cost_reg) and Min Cost (min_additions)
                    if (point_cost_reg < min_additions) begin
                        result <= point_cost_reg;
                    end else begin
                        result <= min_additions;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule