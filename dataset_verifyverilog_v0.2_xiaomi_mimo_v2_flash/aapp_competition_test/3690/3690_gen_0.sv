module clock_path (
    input clk,
    input rst_n,
    input start,
    input [5:0] h,
    input [5:0] m,
    input [5:0] s,
    input [5:0] t1,
    input [5:0] t2,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE      = 3'b000;
    localparam CALC_POS  = 3'b001;
    localparam CHECK_CW  = 3'b010;
    localparam CHECK_CCW = 3'b011;
    localparam FINISH    = 3'b100;

    // Registers for State and Data
    reg [2:0] current_state, next_state;
    reg [5:0] hour_idx, min_idx, sec_idx;
    reg [5:0] start_idx, end_idx;
    reg cw_blocked, ccw_blocked;
    reg [5:0] curr_iter; // Current index being checked
    reg cw_done_flag, ccw_done_flag;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic and Data Processing
    always @(*) begin
        // Default next state to prevent latching
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_POS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CALC_POS: begin
                // One cycle for calculation, move to CW check
                next_state = CHECK_CW;
            end
            
            CHECK_CW: begin
                // Iterate 60 times max, or stop early if blocked
                // If we reached end_idx (assuming start != end), path is clear
                if (curr_iter == end_idx && !cw_blocked) begin
                    next_state = CHECK_CCW;
                end else if (cw_blocked) begin
                    next_state = CHECK_CCW;
                end else begin
                    next_state = CHECK_CW;
                end
                // Special case: if start == end, path is trivially clear (0 length)
                if (start_idx == end_idx) next_state = CHECK_CCW;
            end
            
            CHECK_CCW: begin
                // Iterate 60 times max, or stop early if blocked
                if (curr_iter == end_idx && !ccw_blocked) begin
                    next_state = FINISH;
                end else if (ccw_blocked) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_CCW;
                end
                // Special case: if start == end
                if (start_idx == end_idx) next_state = FINISH;
            end
            
            FINISH: begin
                // Wait for start to go low to return to IDLE to be ready for next trigger
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output Logic (State Machine Actions)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            hour_idx <= 0;
            min_idx <= 0;
            sec_idx <= 0;
            start_idx <= 0;
            end_idx <= 0;
            cw_blocked <= 0;
            ccw_blocked <= 0;
            curr_iter <= 0;
            cw_done_flag <= 0;
            ccw_done_flag <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                end

                CALC_POS: begin
                    // Convert inputs to indices
                    hour_idx <= (h % 12) * 5;
                    min_idx <= m;
                    sec_idx <= s;
                    start_idx <= (t1 % 12) * 5;
                    end_idx <= (t2 % 12) * 5;
                    
                    // Initialize path check flags
                    cw_blocked <= 0;
                    ccw_blocked <= 0;
                    cw_done_flag <= 0;
                    ccw_done_flag <= 0;
                end

                CHECK_CW: begin
                    // Initialize iterator if just entered
                    if (!cw_done_flag) begin
                        cw_done_flag <= 1;
                        // Start checking from start_idx + 1
                        curr_iter <= start_idx + 1;
                    end else begin
                        // Check current iteration
                        // If current index is a hand, block path
                        if (curr_iter == hour_idx || curr_iter == min_idx || curr_iter == sec_idx) begin
                            cw_blocked <= 1;
                        end
                        
                        // Move to next index
                        curr_iter <= curr_iter + 1;
                    end
                end

                CHECK_CCW: begin
                    // Initialize iterator if just entered
                    if (!ccw_done_flag) begin
                        ccw_done_flag <= 1;
                        // Start checking from start_idx - 1
                        // Handle wrap around (if start_idx is 0, go to 59)
                        if (start_idx == 0)
                            curr_iter <= 6'd59;
                        else
                            curr_iter <= start_idx - 1;
                    end else begin
                        // Check current iteration
                        if (curr_iter == hour_idx || curr_iter == min_idx || curr_iter == sec_idx) begin
                            ccw_blocked <= 1;
                        end
                        
                        // Move to next index (decrement with wrap)
                        if (curr_iter == 0)
                            curr_iter <= 6'd59;
                        else
                            curr_iter <= curr_iter - 1;
                    end
                end

                FINISH: begin
                    done <= 1;
                    // If either path is not blocked, result is 1 (YES)
                    // Note: If start == end, both blocked flags are 0, so result is 1.
                    result <= !cw_blocked || !ccw_blocked;
                end
            endcase
        end
    end

endmodule