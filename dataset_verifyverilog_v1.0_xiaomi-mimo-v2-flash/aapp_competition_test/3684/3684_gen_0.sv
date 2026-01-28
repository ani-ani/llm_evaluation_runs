module MaxMinBuffer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] C,
    input wire [15:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [15:0] p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15,
    input wire [15:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    input wire [15:0] b_8, b_9, b_10, b_11, b_12, b_13, b_14, b_15,
    input wire [15:0] u_0, u_1, u_2, u_3, u_4, u_5, u_6, u_7,
    input wire [15:0] u_8, u_9, u_10, u_11, u_12, u_13, u_14, u_15,
    output reg [15:0] result,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1;
    localparam [2:0] CHECK_FEAS = 3'd2;
    localparam [2:0] UPDATE_BOUNDS = 3'd3;
    localparam [2:0] CALC_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Search Variables (Signed for range -256 to 256)
    reg signed [15:0] low;
    reg signed [15:0] high;
    reg signed [15:0] mid;
    reg signed [15:0] best_B;
    
    // Loop Counters
    reg [3:0] user_idx;
    
    // Intermediate Calculation Registers
    reg signed [15:0] p_val;
    reg signed [15:0] b_val;
    reg signed [15:0] u_val;
    reg signed [15:0] target;
    reg signed [15:0] deficit;
    reg signed [15:0] total_deficit;
    reg signed [15:0] total_surplus_cap;
    reg signed [15:0] c_signed;
    
    // Feasibility Result Flag
    reg feasible;

    // Helper to select input based on index
    function automatic [15:0] select_input(
        input [3:0] idx,
        input [15:0] i0, i1, i2, i3, i4, i5, i6, i7,
        input [15:0] i8, i9, i10, i11, i12, i13, i14, i15
    );
        case (idx)
            4'd0: select_input = i0;
            4'd1: select_input = i1;
            4'd2: select_input = i2;
            4'd3: select_input = i3;
            4'd4: select_input = i4;
            4'd5: select_input = i5;
            4'd6: select_input = i6;
            4'd7: select_input = i7;
            4'd8: select_input = i8;
            4'd9: select_input = i9;
            4'd10: select_input = i10;
            4'd11: select_input = i11;
            4'd12: select_input = i12;
            4'd13: select_input = i13;
            4'd14: select_input = i14;
            4'd15: select_input = i15;
            default: select_input = 16'd0;
        endcase
    endfunction

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            low <= 16'sd0;
            high <= 16'sd0;
            mid <= 16'sd0;
            best_B <= 16'sd0;
            user_idx <= 4'd0;
            total_deficit <= 16'sd0;
            total_surplus_cap <= 16'sd0;
            feasible <= 1'b0;
            c_signed <= 16'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        c_signed <= {8'd0, C};
                    end
                end
                
                SETUP: begin
                    // Initialize Binary Search: Range [-256, 256]
                    low <= -16'sd256;
                    high <= 16'sd256;
                    best_B <= -16'sd257; // Impossible low value
                    user_idx <= 4'd0;
                    total_deficit <= 16'sd0;
                    total_surplus_cap <= 16'sd0;
                end
                
                CHECK_FEAS: begin
                    // Collect inputs for current user_idx
                    p_val <= select_input(user_idx, p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7, p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15);
                    b_val <= select_input(user_idx, b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7, b_8, b_9, b_10, b_11, b_12, b_13, b_14, b_15);
                    u_val <= select_input(user_idx, u_0, u_1, u_2, u_3, u_4, u_5, u_6, u_7, u_8, u_9, u_10, u_11, u_12, u_13, u_14, u_15);
                    
                    if (user_idx == n - 1) begin
                        // Check feasibility condition at end of loop
                        // Condition: Total Deficit <= Total Surplus Capacity
                        if (total_deficit <= total_surplus_cap) feasible <= 1'b1;
                        else feasible <= 1'b0;
                    end else begin
                        // Accumulate for next iteration
                        // Target = p + C + B (using mid as B)
                        target <= p_val + c_signed + mid;
                        
                        // Deficit calculation (clamped to 0 if target <= b)
                        if ((p_val + c_signed + mid) > b_val) begin
                            deficit <= (p_val + c_signed + mid) - b_val;
                        end else begin
                            deficit <= 16'sd0;
                        end
                        
                        // Surplus Capacity: If b > target, user has data to give.
                        // Limited by upload capacity u_val.
                        if (b_val > (p_val + c_signed + mid)) begin
                            total_surplus_cap <= total_surplus_cap + u_val;
                        end
                    end
                end
                
                UPDATE_BOUNDS: begin
                    if (feasible) begin
                        best_B <= mid;
                        low <= mid + 16'sd1;
                    end else begin
                        high <= mid - 16'sd1;
                    end
                end
                
                CALC_RESULT: begin
                    result <= best_B;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
            end
            
            SETUP: begin
                next_state = CHECK_FEAS;
            end
            
            CHECK_FEAS: begin
                if (user_idx < n - 1) begin
                    next_state = CHECK_FEAS; // Stay in loop
                end else begin
                    next_state = UPDATE_BOUNDS; // Loop finished, check result
                end
            end
            
            UPDATE_BOUNDS: begin
                if (low <= high) begin
                    next_state = SETUP; // Continue binary search
                end else begin
                    next_state = CALC_RESULT; // Search complete
                end
            end
            
            CALC_RESULT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                if (!start) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Control Signal Updates (Non-sequential logic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            user_idx <= 4'd0;
            total_deficit <= 16'sd0;
            total_surplus_cap <= 16'sd0;
            mid <= 16'sd0;
        end else begin
            case (state)
                SETUP: begin
                    user_idx <= 4'd0;
                    total_deficit <= 16'sd0;
                    total_surplus_cap <= 16'sd0;
                    mid <= (low + high) >>> 1;
                end
                
                CHECK_FEAS: begin
                    if (user_idx < n - 1) begin
                        user_idx <= user_idx + 4'd1;
                        total_deficit <= total_deficit + deficit;
                        // total_surplus_cap updated in previous clock or combinational if needed, 
                        // but here we rely on the accumulated value in the register.
                        // Note: The update logic in CHECK_FEAS block updates total_surplus_cap for the *next* cycle.
                        // This sequential block needs to handle accumulation carefully.
                        // Actually, better to do accumulation in the sequential block based on state transition.
                        
                        // Re-evaluating accumulation:
                        // If we move to next user, we need to add calculated deficit and surplus to running totals.
                        // Since 'deficit' and 'surplus' calc happened in CHECK_FEAS (combinational usually, but here sequential),
                        // we use the values computed in the previous clock cycle.
                        
                        // Wait, the logic inside CHECK_FEAS (sequential block) updates p_val, b_val etc.
                        // The deficit calculation depends on those values. 
                        // We need to ensure deficit is valid when we add it.
                        // Since this is a single clock cycle per user check, we calculate deficit in the *next* cycle logic or combinational.
                        // Let's assume the values p_val, b_val etc. were captured in the *previous* cycle of CHECK_FEAS.
                        // So when we are in CHECK_FEAS state, we can compute deficit based on stored p_val, b_val, mid.
                        // Then when transitioning to next user, we update totals.
                    end
                end
                
                UPDATE_BOUNDS: begin
                    // Reset for next search iteration or finish
                end
                
                default: begin
                    user_idx <= user_idx;
                end
            endcase
        end
    end
    
    // Correction for Accumulation:
    // The logic inside CHECK_FEAS sequential block must happen before we increment user_idx.
    // Let's refactor the CHECK_FEAS sequential logic to handle the loop index update and accumulation.
    
    // Let's rewrite the CHECK_FEAS block inside the sequential always block for correctness.
    // The previous implementation had logic in the combinational block, which is tricky for loops.
    
    // Reset the accumulation registers in SETUP (done above).
    // In CHECK_FEAS state:
    // 1. Fetch data for current user_idx.
    // 2. Calculate deficit/surplus.
    // 3. If user_idx < n-1, accumulate and increment.
    // 4. If user_idx == n-1, accumulate and check feasibility.
    
    // Since we cannot do 2 operations (fetch calc + accumulate next) in one clock easily without combinational help,
    // we will do:
    // Cycle 1: Load p_val, b_val for index k. Compute deficit/surplus for index k.
    // Cycle 2: Add to totals, increment index. If index < n, go to Cycle 1.
    
    // This doubles the loop time but is safer for synchronous logic.
    
    // Let's remove the previous accumulation logic in CHECK_FEAS and use a dedicated state or better flow.
    
    // Revised CHECK_FEAS flow:
    // State CHECK_FEAS:
    //   Load data for user_idx.
    //   If user_idx == 0, totals are 0.
    //   Next State: CHECK_ACCUM
    // State CHECK_ACCUM:
    //   Add calculated deficit/surplus to totals.
    //   Increment user_idx.
    //   If user_idx < n, go to CHECK_FEAS.
    //   If user_idx == n, go to UPDATE_BOUNDS.
    
    // We need an extra state: CHECK_ACCUM.
    
    // Let's add CHECK_ACCUM state logic.

endmodule

// To make it work within the constraints of the prompt (efficient code) without adding too many states:
// We will use combinational logic for the 'deficit' calculation to keep the loop fast (1 cycle per user).
// The sequential block will handle the accumulation.

module MaxMinBuffer_V2(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] C,
    input wire [15:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [15:0] p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15,
    input wire [15:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    input wire [15:0] b_8, b_9, b_10, b_11, b_12, b_13, b_14, b_15,
    input wire [15:0] u_0, u_1, u_2, u_3, u_4, u_5, u_6, u_7,
    input wire [15:0] u_8, u_9, u_10, u_11, u_12, u_13, u_14, u_15,
    output reg [15:0] result,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1;
    localparam [2:0] LOOP_LOAD = 3'd2;
    localparam [2:0] LOOP_ACCUM = 3'd3;
    localparam [2:0] UPDATE_BOUNDS = 3'd4;
    localparam [2:0] CALC_RESULT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Internal Registers
    reg [2:0] state;
    
    // Search Variables
    reg signed [15:0] low;
    reg signed [15:0] high;
    reg signed [15:0] mid;
    reg signed [15:0] best_B;
    
    // Loop Counters
    reg [3:0] user_idx;
    
    // Data Registers for Current User
    reg signed [15:0] p_reg;
    reg signed [15:0] b_reg;
    reg signed [15:0] u_reg;
    
    // Accumulators
    reg signed [15:0] total_deficit;
    reg signed [15:0] total_surplus_cap;
    
    // Intermediate Calculation (Combinational)
    wire signed [15:0] c_signed;
    assign c_signed = {8'd0, C};
    
    wire signed [15:0] target;
    assign target = p_reg + c_signed + mid;
    
    wire signed [15:0] diff;
    assign diff = target - b_reg;
    
    wire signed [15:0] deficit_i;
    assign deficit_i = (diff > 0) ? diff : 16'sd0;
    
    wire signed [15:0] surplus_cap_i;
    assign surplus_cap_i = (b_reg > target) ? u_reg : 16'sd0;
    
    // Feasibility Check
    wire feasible;
    assign feasible = (total_deficit <= total_surplus_cap);

    // Helper Function
    function automatic [15:0] select_input(
        input [3:0] idx,
        input [15:0] i0, i1, i2, i3, i4, i5, i6, i7,
        input [15:0] i8, i9, i10, i11, i12, i13, i14, i15
    );
        case (idx)
            4'd0: select_input = i0; 4'd1: select_input = i1;
            4'd2: select_input = i2; 4'd3: select_input = i3;
            4'd4: select_input = i4; 4'd5: select_input = i5;
            4'd6: select_input = i6; 4'd7: select_input = i7;
            4'd8: select_input = i8; 4'd9: select_input = i9;
            4'd10: select_input = i10; 4'd11: select_input = i11;
            4'd12: select_input = i12; 4'd13: select_input = i13;
            4'd14: select_input = i14; 4'd15: select_input = i15;
            default: select_input = 16'd0;
        endcase
    endfunction

    // State Transition and Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            low <= 16'sd0;
            high <= 16'sd0;
            mid <= 16'sd0;
            best_B <= 16'sd0;
            user_idx <= 4'd0;
            total_deficit <= 16'sd0;
            total_surplus_cap <= 16'sd0;
            p_reg <= 16'sd0;
            b_reg <= 16'sd0;
            u_reg <= 16'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= SETUP;
                end
                
                SETUP: begin
                    low <= -16'sd256;
                    high <= 16'sd256;
                    best_B <= -16'sd257;
                    mid <= 16'sd0; // Will be calc'd in LOOP_LOAD
                    state <= LOOP_LOAD;
                end
                
                LOOP_LOAD: begin
                    // Check termination condition of binary search (handled in UPDATE_BOUNDS)
                    // Here we handle the termination of the user loop
                    if (user_idx >= n) begin
                        // Finished loop over all users. Check feasibility.
                        if (feasible && mid > best_B) begin
                            best_B <= mid;
                        end
                        state <= UPDATE_BOUNDS;
                    end else begin
                        // Load data for current user
                        p_reg <= select_input(user_idx, p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7, p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15);
                        b_reg <= select_input(user_idx, b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7, b_8, b_9, b_10, b_11, b_12, b_13, b_14, b_15);
                        u_reg <= select_input(user_idx, u_0, u_1, u_2, u_3, u_4, u_5, u_6, u_7, u_8, u_9, u_10, u_11, u_12, u_13, u_14, u_15);
                        state <= LOOP_ACCUM;
                    end
                end
                
                LOOP_ACCUM: begin
                    // Accumulate calculated values (combinational)
                    total_deficit <= total_deficit + deficit_i;
                    total_surplus_cap <= total_surplus_cap + surplus_cap_i;
                    
                    // Move to next user
                    user_idx <= user_idx + 4'd1;
                    state <= LOOP_LOAD;
                end
                
                UPDATE_BOUNDS: begin
                    if (low <= high) begin
                        if (feasible) begin
                            low <= mid + 16'sd1;
                        end else begin
                            high <= mid - 16'sd1;
                        end
                        // Prepare for next iteration
                        user_idx <= 4'd0;
                        total_deficit <= 16'sd0;
                        total_surplus_cap <= 16'sd0;
                        // Update mid for next search (calculation done in LOOP_LOAD when n=0 is handled, but here we set it)
                        // We need mid for the feasibility check. 
                        // mid is computed as (low+high)/2. We do it here.
                        // If we updated low/high, we need new mid.
                        // If we exit search (low > high), we go to CALC_RESULT.
                        state <= LOOP_LOAD; // Go to loop load (which will check n>=0 immediately)
                    end else begin
                        state <= CALC_RESULT;
                    end
                end
                
                CALC_RESULT: begin
                    // best_B might be -257 if no feasible found in range, clamp to low bound
                    if (best_B < -16'sd256) result <= -16'sd256;
                    else result <= best_B;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Mid calculation logic (separate to avoid combinational loops)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mid <= 16'sd0;
        end else begin
            if (state == SETUP) begin
                mid <= (low + high) >>> 1;
            end else if (state == UPDATE_BOUNDS && low <= high) begin
                mid <= (low + high) >>> 1;
            end
        end
    end

endmodule