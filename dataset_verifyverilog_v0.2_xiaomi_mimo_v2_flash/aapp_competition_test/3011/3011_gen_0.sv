module hill_counter(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam S_IDLE = 4'd0;
    localparam S_DIGITIZE = 4'd1;
    localparam S_CHECK_HILL = 4'd2;
    localparam S_NOT_HILL = 4'd3;
    localparam S_COUNT_INIT = 4'd4;
    localparam S_COUNT_DP = 4'd5;
    localparam S_DONE = 4'd6;

    reg [3:0] state, next_state;
    
    // Digits
    reg [3:0] digits [3:0];
    
    // Hill Check
    reg [1:0] hc_idx;
    reg hc_is_hill;
    reg hc_seen_fall;
    
    // DP Registers
    reg [31:0] dp_res;
    reg [1:0] dp_pos;
    reg dp_phase; // 0: Rising, 1: Falling
    reg dp_tight;
    reg dp_started;
    reg [3:0] dp_digit;
    reg [3:0] dp_prev_digit;
    reg [2:0] dp_sub_state;
    reg [4:0] sp;
    
    // Stack
    reg [1:0] saved_pos [31:0];
    reg saved_phase [31:0];
    reg saved_tight [31:0];
    reg saved_started [31:0];
    reg [3:0] saved_digit [31:0];
    reg [31:0] saved_accum [31:0];
    reg [3:0] saved_prev_digit [31:0];

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: if (start) next_state = S_DIGITIZE;
            
            S_DIGITIZE: next_state = S_CHECK_HILL;
            
            S_CHECK_HILL: begin
                if (hc_idx == 3) begin
                    // At index 3, we perform the last comparison (digits[2] vs digits[3])
                    // The update happens in sequential logic at this edge.
                    // So we need one more cycle to commit the result, or do it combinational.
                    // To save cycles, let's say we finish at idx 4.
                end
                if (hc_idx == 4) next_state = hc_is_hill ? S_COUNT_INIT : S_NOT_HILL;
            end
            
            S_NOT_HILL: next_state = S_DONE;
            
            S_COUNT_INIT: next_state = S_COUNT_DP;
            
            S_COUNT_DP: begin
                // Sub-state transitions
                if (dp_sub_state == 3 && sp == 0) next_state = S_DONE; // Finished all
                else next_state = S_COUNT_DP; // Keep processing
            end
            
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
            done <= (next_state == S_DONE);
            
            // Result update
            if (state == S_COUNT_DP && dp_sub_state == 3 && sp == 0) begin
                result <= dp_res;
            end else if (state == S_NOT_HILL) begin
                result <= 32'hFFFFFFFF;
            end
            
            // S_IDLE
            if (state == S_IDLE && start) begin
                // Reset counters
                hc_idx <= 0;
            end
            
            // S_DIGITIZE
            if (state == S_DIGITIZE) begin
                digits[0] <= n[3:0];
                digits[1] <= n[7:4];
                digits[2] <= n[11:8];
                digits[3] <= n[15:12];
            end
            
            // S_CHECK_HILL
            if (state == S_CHECK_HILL) begin
                if (hc_idx < 4) begin
                    if (hc_idx == 0) begin
                        hc_is_hill <= 1;
                        hc_seen_fall <= 0;
                    end else begin
                        // Compare digits[hc_idx-1] and digits[hc_idx]
                        if (digits[hc_idx-1] < digits[hc_idx]) begin
                            if (hc_seen_fall) hc_is_hill <= 0;
                        end else if (digits[hc_idx-1] > digits[hc_idx]) begin
                            hc_seen_fall <= 1;
                        end
                    end
                    hc_idx <= hc_idx + 1;
                end
            end
            
            // S_COUNT_INIT
            if (state == S_COUNT_INIT) begin
                dp_res <= 0;
                dp_pos <= 0;
                dp_phase <= 0;
                dp_tight <= 1;
                dp_started <= 0;
                dp_prev_digit <= 0;
                dp_digit <= 0;
                sp <= 0;
                dp_sub_state <= 0;
            end
            
            // S_COUNT_DP
            if (state == S_COUNT_DP) begin
                case (dp_sub_state)
                    0: begin // Check & Decide
                        // Determine max digit for loop
                        // (In combinational logic or here? Let's do it here to avoid timing loops)
                        // But we need it for the ' > max' check.
                        // Let's use a wire for max_d in the if condition.
                        // Actually, synthesis will flatten it.
                        // We'll use a local variable in the block.
                        
                        if (dp_digit > (dp_tight ? digits[dp_pos] : 4'd9)) begin
                            // Loop finished, Return
                            if (sp > 0) dp_sub_state <= 3;
                            else dp_sub_state <= 3; // Will trigger done
                        end else begin
                            // Valid digit value. Check Hill constraints.
                            // Validity check:
                            // If not started and digit==0: Valid (but don't start)
                            // If not started and digit!=0: Valid (Start)
                            // If started:
                            //   If Phase 0 (Rising): If digit >= prev. If digit < prev, switch to Phase 1.
                            //   If Phase 1 (Falling): If digit <= prev. If digit > prev, Invalid.
                            
                            reg valid;
                            valid = 1;
                            if (dp_started) begin
                                if (dp_phase == 0) begin
                                    if (dp_digit < dp_prev_digit) valid = 1; // Switch to falling, ok
                                end else begin // Phase 1
                                    if (dp_digit > dp_prev_digit) valid = 0; // Rise after fall
                                end
                            end
                            
                            if (valid) begin
                                // If we are at the last position (pos 3), accumulate leaf
                                if (dp_pos == 3) begin
                                    if (dp_started || dp_digit != 0) dp_res <= dp_res + 1;
                                    dp_digit <= dp_digit + 1; // Continue loop
                                end else begin
                                    // Recurse
                                    dp_sub_state <= 1;
                                end
                            end else begin
                                // Invalid, skip
                                dp_digit <= dp_digit + 1;
                            end
                        end
                    end
                    
                    1: begin // Recurse (Push & Setup Child)
                        // Save context
                        if (sp < 32) begin
                            saved_pos[sp] <= dp_pos;
                            saved_phase[sp] <= dp_phase;
                            saved_tight[sp] <= dp_tight;
                            saved_started[sp] <= dp_started;
                            saved_digit[sp] <= dp_digit;
                            saved_accum[sp] <= dp_res;
                            saved_prev_digit[sp] <= dp_prev_digit;
                            sp <= sp + 1;
                            
                            // Setup Child
                            dp_pos <= dp_pos + 1;
                            
                            // Update Phase for child
                            if (!dp_started) dp_phase <= 0;
                            else if (dp_phase == 0 && dp_digit < dp_prev_digit) dp_phase <= 1;
                            else dp_phase <= dp_phase;
                            
                            // Update Tight
                            if (dp_tight && dp_digit == digits[dp_pos]) dp_tight <= 1;
                            else dp_tight <= 0;
                            
                            // Update Started
                            if (dp_started) dp_started <= 1;
                            else dp_started <= (dp_digit != 0);
                            
                            // Update Prev Digit
                            dp_prev_digit <= dp_digit;
                            
                            // Reset Child Loop
                            dp_digit <= 0;
                            dp_res <= 0;
                            
                            dp_sub_state <= 0;
                        end else begin
                            // Safety: should not happen in valid input range
                            dp_sub_state <= 0;
                            dp_digit <= dp_digit + 1;
                        end
                    end
                    
                    3: begin // Pop (Return from Recursion)
                        if (sp > 0) begin
                            // Add child result to parent
                            sp <= sp - 1;
                            dp_res <= saved_accum[sp-1] + dp_res;
                            
                            // Restore Parent Context
                            dp_pos <= saved_pos[sp-1];
                            dp_phase <= saved_phase[sp-1];
                            dp_tight <= saved_tight[sp-1];
                            dp_started <= saved_started[sp-1];
                            dp_prev_digit <= saved_prev_digit[sp-1];
                            
                            // Increment Parent Loop
                            dp_digit <= saved_digit[sp-1] + 1;
                            
                            dp_sub_state <= 0;
                        end else begin
                            // Sp=0, Pop called but no parent. This is the final return.
                            // Sub_state remains 3. Main FSM will transition to DONE.
                        end
                    end
                endcase
            end
            
            // S_DONE
            // (Handled by done output and next_state transition)
            if (state == S_DONE && !start) begin
                // Reset if needed, but handled by S_IDLE transition
            end
        end
    end

endmodule