module clock_misha (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] h,
    input wire [5:0] m,
    input wire [5:0] s,
    input wire [3:0] t1,
    input wire [3:0] t2,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC = 3'd1;
    localparam [2:0] CHECK_CW = 3'd2;
    localparam [2:0] CHECK_CCW = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Registers
    reg [2:0] state;
    reg [5:0] pos_h, pos_m, pos_s;
    reg [5:0] t1_norm, t2_norm;
    reg [5:0] pos_h_check, pos_m_check, pos_s_check;
    reg [5:0] check_limit_low, check_limit_high;
    reg path_clear;
    reg cw_clear, ccw_clear;
    reg [2:0] step; // Tracks which hand we are checking
    reg [2:0] cycle_count; // Prevent infinite loops

    // Hand position calculation
    wire [5:0] hour_mod = h % 12;
    wire [5:0] pos_h_wire = hour_mod * 5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            pos_h <= 6'd0;
            pos_m <= 6'd0;
            pos_s <= 6'd0;
            t1_norm <= 6'd0;
            t2_norm <= 6'd0;
            pos_h_check <= 6'd0;
            pos_m_check <= 6'd0;
            pos_s_check <= 6'd0;
            check_limit_low <= 6'd0;
            check_limit_high <= 6'd0;
            path_clear <= 1'b0;
            cw_clear <= 1'b0;
            ccw_clear <= 1'b0;
            step <= 3'd0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Calculate initial positions and normalize t1, t2
                        pos_h <= pos_h_wire;
                        pos_m <= m;
                        pos_s <= s;
                        t1_norm <= t1 * 5;
                        t2_norm <= t2 * 5;
                        state <= CALC;
                        cycle_count <= 3'd0;
                    end
                end

                CALC: begin
                    // Ensure t1_norm < t2_norm for clockwise check
                    // If t1 > t2, we swap for CW check to represent the smaller arc
                    // Actually, the problem states: Ensure t1 < t2. 
                    // But t1 and t2 are inputs. We must handle both cases.
                    // CW path is t1 -> t2 (shortest clockwise arc). 
                    // CCW path is t2 -> t1 (shortest counter-clockwise arc).
                    // The logic "Ensure t1 < t2" in the prompt implies we fix an orientation.
                    // Let's stick to the mathematical definition:
                    // CW path: interval (t1, t2) if t1 < t2, else (t1, 60) U (0, t2)
                    // Prompt says: "Ensure t1 < t2".
                    // Let's normalize so t1 is always the lower bound for the CW interval.
                    // If t1 > t2, swap them for the purpose of CW check, but remember to swap back for result logic? 
                    // No, the prompt says: "Normalize t1 and t2 to 0-59 range (t1*5, t2*5). Ensure t1 < t2."
                    // This suggests we are defining a canonical CW interval.
                    // However, the physical start and end matters. 
                    // Let's follow the explicit instructions in the prompt for the CW check logic.
                    // "Clockwise Check: If pos_h, pos_m, pos_s are all outside the open interval (t1, t2)"
                    // This implies we need to establish a CW interval.
                    // Let's calculate t1, t2 normalized. 
                    // If t1 < t2: interval is (t1, t2)
                    // If t1 > t2: interval is (t1, 60) U (0, t2) -> this is harder to check with a single interval check.
                    // But the prompt simplifies: "Ensure t1 < t2".
                    // Let's assume the inputs are such that we calculate the arc that goes from min(t1, t2) to max(t1, t2)?
                    // No, "Misha can move in two directions".
                    // Direction 1: Clockwise. Path is t1 -> t2 (wrapping if needed).
                    // Let's follow the specific logic in the prompt for the counter-clockwise check: 
                    // "map t1 to t1 + 60".
                    // This implies for CCW, we check interval (t2, t1+60).
                    // For CW, the interval is (t1, t2) if t1 < t2, or (t1, 60) U (0, t2) if t1 > t2.
                    // The prompt says: "Ensure t1 < t2". 
                    // Let's do this: 
                    // For CW check, we check the interval going from t1 to t2 clockwise.
                    // If t1 < t2, interval is (t1, t2).
                    // If t1 > t2, interval wraps around. We check hands NOT in (t1, 60) AND NOT in (0, t2).
                    // However, the prompt explicitly gives the logic for CCW: (t2, t1+60).
                    // This implies t1 is always the start and t2 is always the target in the clock-wise orientation of the circle?
                    // No, the prompt says: "Ensure t1 < t2" in the normalization step. 
                    // I will interpret "Ensure t1 < t2" as "Define the clockwise arc as the arc from the smaller index to the larger index".
                    // BUT wait, the inputs are `t1` (Start) and `t2` (Target). 
                    // If Start > Target, going Clockwise wraps around 60->0.
                    // Let's stick to the most robust interpretation that matches the prompt's explicit formulas.
                    // The prompt's CW check: (t1, t2). This is valid only if t1 < t2.
                    // The prompt's CCW check: (t2, t1+60). This works if we assume t1 < t2.
                    // If t1 > t2, then (t1, t2) is empty in linear space, but represents the long arc in circular space.
                    // The problem is a discrete check: is there a clear arc?
                    // Let's assume the prompt implies t1 and t2 are mapped such that we check two arcs:
                    // Arc 1: From t1 to t2 going forward (clockwise).
                    // Arc 2: From t2 to t1 going forward (which is counter-clockwise from t1).
                    // To implement this simply:
                    // Define interval 1 (CW): 
                    //   if t1 < t2: check (t1, t2)
                    //   else: check (t1, 60) U (0, t2)
                    // Define interval 2 (CCW):
                    //   if t1 < t2: check (t2, 60) U (0, t1) -> which is check (t2, t1+60)
                    //   else: check (t2, t1)
                    // 
                    // Let's use the "Ensure t1 < t2" logic from the prompt. 
                    // It says: "Normalize t1 and t2 to 0-59 range (t1*5, t2*5). Ensure t1 < t2."
                    // I will swap t1 and t2 if t1 > t2 to satisfy this condition for the *check logic*.
                    // BUT, this loses the direction information. 
                    // Example: Start=11, Target=1. Clockwise is short. CCW is long.
                    // If I swap to t1=1, t2=11.
                    // Check 1 (Clockwise from 1 to 11): Checks interval (1, 11). 
                    // Check 2 (Counter-clockwise from 1 to 11): Checks interval (11, 61) -> (11, 1).
                    // This correctly identifies the two disjoint arcs. 
                    // So, swapping t1 and t2 if t1 > t2 works to simplify the interval checks.
                    
                    if (t1_norm > t2_norm) begin
                        t1_norm <= t2_norm;
                        t2_norm <= t1_norm;
                    end
                    
                    // Initialize check variables
                    cw_clear <= 1'b1;
                    ccw_clear <= 1'b1;
                    step <= 3'd0;
                    state <= CHECK_CW;
                end

                CHECK_CW: begin
                    // Check interval (t1_norm, t2_norm)
                    // We check each hand: pos, pos+60, pos-60 against the interval
                    // If any hand is inside, cw_clear = 0
                    
                    // We will verify one hand per cycle to keep it simple
                    case (step)
                        3'd0: begin // Check Hour
                            if (is_inside(pos_h, t1_norm, t2_norm)) cw_clear <= 1'b0;
                            step <= 3'd1;
                        end
                        3'd1: begin // Check Minute
                            if (is_inside(pos_m, t1_norm, t2_norm)) cw_clear <= 1'b0;
                            step <= 3'd2;
                        end
                        3'd2: begin // Check Second
                            if (is_inside(pos_s, t1_norm, t2_norm)) cw_clear <= 1'b0;
                            step <= 3'd0;
                            state <= CHECK_CCW;
                        end
                        default: step <= 3'd0;
                    endcase
                end

                CHECK_CCW: begin
                    // Check interval (t2_norm, t1_norm + 60)
                    // Equivalent to checking if hands are in (t2_norm, 60) U (0, t1_norm)
                    // We check if hands are inside (t2_norm, t1_norm + 60)
                    
                    case (step)
                        3'd0: begin // Check Hour
                            if (is_inside_ccw(pos_h, t2_norm, t1_norm)) ccw_clear <= 1'b0;
                            step <= 3'd1;
                        end
                        3'd1: begin // Check Minute
                            if (is_inside_ccw(pos_m, t2_norm, t1_norm)) ccw_clear <= 1'b0;
                            step <= 3'd2;
                        end
                        3'd2: begin // Check Second
                            if (is_inside_ccw(pos_s, t2_norm, t1_norm)) ccw_clear <= 1'b0;
                            step <= 3'd0;
                            state <= FINISH;
                        end
                        default: step <= 3'd0;
                    endcase
                end

                FINISH: begin
                    result <= cw_clear | ccw_clear;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Helper function (combinational logic)
    // Check if pos is strictly inside (low, high)
    function automatic logic is_inside(input [5:0] pos, input [5:0] low, input [5:0] high);
        logic [5:0] pos_adj;
        // Adjust position to be relative to low
        // Since we ensured low < high in CALC state
        if (pos > low && pos < high) begin
            return 1'b1;
        end else begin
            return 1'b0;
        end
    endfunction

    // Check if pos is inside (low, high) where high can be > 60
    // Here low = t2, high = t1 + 60
    function automatic logic is_inside_ccw(input [5:0] pos, input [5:0] low, input [5:0] t1_orig);
        logic [5:0] pos_shifted;
        logic [5:0] high;
        
        high = t1_orig + 60; // This is guaranteed to be > 60
        
        // We check if (pos is in (low, 60)) OR (pos is in (0, t1_orig))
        // This is equivalent to checking (pos + 60) in (low + 60, t1_orig + 60) ?
        // No, better to check directly:
        // Condition 1: low < pos < 60
        // Condition 2: 0 < pos < t1_orig
        
        if ((pos > low && pos < 60) || (pos > 0 && pos < t1_orig)) begin
            return 1'b1;
        end else begin
            return 1'b0;
        end
    endfunction

endmodule