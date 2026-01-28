module poly_base_neg_k (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] p,
    input wire [15:0] k,
    output reg [15:0] coeff [0:31],
    output reg [5:0] len,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_ZERO = 3'd1;
    localparam [2:0] CALC_REM   = 3'd2;
    localparam [2:0] CALC_CURR  = 3'd3;
    localparam [2:0] STORE_COEF = 3'd4;
    localparam [2:0] FINISH_OK  = 3'd5;
    localparam [2:0] FINISH_ERR = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg signed [63:0] current;
    reg signed [63:0] next_current;
    reg signed [15:0] rem;
    reg [5:0] idx;
    reg [5:0] next_idx;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64; // Safe limit for 32 iterations

    // Temporary signals for arithmetic
    reg signed [63:0] temp_rem;
    reg signed [63:0] temp_div;
    reg signed [63:0] temp_current_minus_rem;

    // coeff array initialization in reset
    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current <= 64'd0;
            rem <= 16'd0;
            idx <= 6'd0;
            cycle_count <= 6'd0;
            done <= 1'b0;
            error <= 1'b0;
            len <= 6'd0;
            // Initialize coeff array
            for (i = 0; i < 32; i = i + 1) begin
                coeff[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            current <= next_current;
            idx <= next_idx;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 6'd0;
                    // Reset coeff array content (optional but safe)
                    for (i = 0; i < 32; i = i + 1) begin
                        coeff[i] <= 16'd0;
                    end
                end
                CALC_REM: begin
                    rem <= temp_rem[15:0];
                end
                STORE_COEF: begin
                    if (idx < 32) begin
                        coeff[idx] <= rem;
                    end
                end
                FINISH_OK: begin
                    len <= idx;
                    done <= 1'b1;
                    error <= 1'b0;
                end
                FINISH_ERR: begin
                    len <= 6'd0;
                    done <= 1'b1;
                    error <= 1'b1;
                end
            endcase
            
            if (start) begin
                cycle_count <= 6'd0;
            end else if (state != IDLE) begin
                if (cycle_count < MAX_CYCLES) begin
                    cycle_count <= cycle_count + 6'd1;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_current = current;
        next_idx = idx;

        case (state)
            IDLE: begin
                if (start) begin
                    next_current = {64{1'b0}} | p; // Sign extend p (p is non-negative)
                    next_idx = 6'd0;
                    next_state = CHECK_ZERO;
                end
            end

            CHECK_ZERO: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH_ERR;
                end else if (current == 64'd0) begin
                    if (idx > 0) begin
                        next_state = FINISH_OK;
                    end else begin
                        // p was 0, technically a solution (len=1, coeff[0]=0) or error?
                        // Spec says p is 1 to 10^18, so p=0 won't happen in valid inputs.
                        // But let's handle it gracefully.
                        next_state = FINISH_OK; // len=0 or 1? Let's say len=1, coeff[0]=0.
                        // However, idx is 0 here. If p=0, it's a special case.
                        // Let's assume if p=0, len=1, coeff[0]=0.
                        // But the loop logic requires idx > 0 for FINISH_OK in spec.
                        // Let's output len=0 for p=0 as error or special case?
                        // Spec: "If current == 0 and idx > 0". If p=0, idx=0.
                        // We will treat p=0 as error per strict interpretation, or just output len=1.
                        // Let's output FINISH_OK but handle idx==0 specifically.
                        // Actually, if p=0, coeffs are just [0].
                        // Let's put 0 into coeff[0] and set len=1.
                        // Wait, if we are here with current=0 and idx=0, it means p=0.
                        // Let's set coeff[0]=0, idx=1, then go to FINISH_OK.
                    end
                end else begin
                    next_state = CALC_REM;
                end
            end

            CALC_REM: begin
                next_state = CALC_CURR;
            end

            CALC_CURR: begin
                next_state = STORE_COEF;
            end

            STORE_COEF: begin
                next_idx = idx + 6'd1;
                // current = (current - rem) / (-k)
                // Note: current - rem is divisible by k.
                // We use temp_div computed in combinational block
                next_current = -temp_div;
                
                if (idx == 6'd31) begin // Max 32 coefficients (0..31)
                    next_state = FINISH_ERR;
                end else begin
                    next_state = CHECK_ZERO;
                end
            end

            FINISH_OK: next_state = IDLE;
            FINISH_ERR: next_state = IDLE;

            default: next_state = IDLE;
        endcase

        // Special handling for p=0 in IDLE->CHECK_ZERO transition
        if (state == CHECK_ZERO && current == 64'd0 && idx == 6'd0 && cycle_count < MAX_CYCLES) begin
             // p=0 case. 
             // Let's produce [0] as solution.
             // We can jump to a state that sets coeff[0]=0, len=1.
             // Or simply modify next_state here.
             // To keep it simple with the FSM structure:
             // We will treat it as a valid solution but need to set coeff[0].
             // Let's go to STORE_COEF to put 0 in coeff[0], then next time CHECK_ZERO sees current=0 and idx=1.
             // But we need current to stay 0. 
             // Actually, if p=0, the loop shouldn't run. 
             // Let's add a special case logic.
             // If p=0, go to FINISH_OK but set len=1, coeff[0]=0.
             // Since we are in combinational block, we can modify next_state directly.
             next_state = FINISH_OK;
             next_idx = 6'd1; // Fake length
             // We also need to set coeff[0]=0.
             // Since we are in combinational logic for next_state, we can't write to coeff array here easily.
             // Better to have a specific state for p=0 or handle it in IDLE.
             // Let's rely on the fact that p >= 1 per input spec.
             // If p=0 is strictly impossible, we don't need this logic.
             // Input spec says: "p[63:0]: input integer (1 to 10^18)"
             // So p=0 is not a valid input. We can ignore p=0 case.
        end
    end

    // Combinational arithmetic logic
    always @(*) begin
        // Default values
        temp_rem = 64'd0;
        temp_div = 64'd0;
        temp_current_minus_rem = 64'd0;

        if (state == CALC_REM) begin
            // rem = current % k
            // Verilog % operator for signed numbers returns remainder with sign of dividend (current).
            // We want remainder in [0, k-1].
            // If rem < 0, rem = rem + k.
            
            temp_rem = current % {48'd0, k};
            
            if (temp_rem < 0) begin
                temp_rem = temp_rem + {48'd0, k};
            end
            // temp_rem is now positive and < k
        end else if (state == CALC_CURR) begin
            // current = (current - rem) / (-k)
            // current - rem is divisible by k.
            // We compute numerator = current - rem
            // Then division by k (signed)
            // Then negate.
            
            temp_current_minus_rem = current - {48'd0, rem};
            // Division: temp_current_minus_rem / {48'd0, k}
            // Verilog division truncates towards zero.
            // Since numerator is divisible by k, no truncation error.
            temp_div = temp_current_minus_rem / {48'd0, k};
        end
    end

endmodule