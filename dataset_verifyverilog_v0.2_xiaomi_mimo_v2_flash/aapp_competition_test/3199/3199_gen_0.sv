module vault_security (
    input clk,
    input rst_n,
    input start,
    input [15:0] L,
    input [10:0] A,
    input [10:0] B,
    output reg [31:0] insecure_count,
    output reg [31:0] secure_count,
    output reg [31:0] super_secure_count,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK_X = 3'b001;
    localparam CHECK_Y = 3'b010;
    localparam GCD_SETUP = 3'b011;
    localparam GCD_CALC = 3'b100;
    localparam CALCULATE = 3'b101;
    localparam DONE = 3'b110;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] x_reg;        // Current x value
    reg [10:0] y_reg;        // Current y value (actual coordinate)
    reg [31:0] ins_cnt;
    reg [31:0] sec_cnt;
    reg [31:0] sup_sec_cnt;

    // GCD Engine Signals
    reg gcd_start;
    reg [31:0] gcd_a_in;
    reg [31:0] gcd_b_in;
    wire [31:0] gcd_result;
    wire gcd_done;
    wire gcd_valid;

    // GCD Controller (Iterative Euclidean Algorithm)
    reg [31:0] gcd_a;
    reg [31:0] gcd_b;
    reg gcd_active;
    reg [1:0] gcd_phase; // 0: swap check, 1: sub/mod, 2: finalize

    assign gcd_valid = gcd_active && (gcd_a == 1 || gcd_b == 1 || (gcd_a == 0 || gcd_b == 0));
    assign gcd_result = (gcd_a == 0) ? gcd_b : gcd_a;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_active <= 1'b0;
            gcd_phase <= 2'b0;
            gcd_a <= 0;
            gcd_b <= 0;
        end else begin
            if (gcd_start) begin
                gcd_a <= gcd_a_in;
                gcd_b <= gcd_b_in;
                gcd_active <= 1'b1;
                gcd_phase <= 2'b0;
            end else if (gcd_active) begin
                // Optimization: Early termination for 1
                if (gcd_a == 1 || gcd_b == 1) begin
                    gcd_active <= 1'b0;
                end else if (gcd_phase == 2'b0) begin
                    // Ensure a >= b
                    if (gcd_a < gcd_b) begin
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_a;\                    end
                    gcd_phase <= 2'b1;
                end else if (gcd_phase == 2'b1) begin
                    // Euclidean step: a = a % b
                    if (gcd_b == 0) begin
                        gcd_active <= 1'b0;
                    end else begin
                        gcd_a <= gcd_a % gcd_b;
                        gcd_phase <= 2'b0; // Loop back to swap check
                        // Check if done after this step
                        if ((gcd_a % gcd_b) == 1) begin
                             gcd_active <= 1'b0;
                        end
                    end
                end
            end
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_X;
                else next_state = IDLE;
            end
            CHECK_X: begin
                if (x_reg > L) next_state = DONE;
                else next_state = CHECK_Y;
            end
            CHECK_Y: begin
                if ($signed(y_reg) > $signed(B)) next_state = INCR_X;
                else next_state = GCD_SETUP;
            end
            GCD_SETUP: next_state = GCD_CALC;
            GCD_CALC: begin
                if (gcd_active == 0 && gcd_valid) next_state = CALCULATE; // GCD finished
                else next_state = GCD_CALC;
            end
            CALCULATE: next_state = CHECK_Y_INCR;
            CHECK_Y_INCR: next_state = CHECK_Y;
            INCR_X: next_state = CHECK_X;
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State Registers and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_reg <= 1;
            y_reg <= 0;
            ins_cnt <= 0;
            sec_cnt <= 0;
            sup_sec_cnt <= 0;
            done <= 0;
            insecure_count <= 0;
            secure_count <= 0;
            super_secure_count <= 0;
            gcd_start <= 0;
        end else begin
            gcd_start <= 0; // Default pulse low
            state <= next_state;

            case (state)
                IDLE: begin
                    x_reg <= 1;
                    y_reg <= -A; // Starting from -A
                    ins_cnt <= 0;
                    sec_cnt <= 0;
                    sup_sec_cnt <= 0;
                    done <= 0;
                    if (start && L == 0) state <= DONE; // Edge case L=0
                end

                CHECK_X: begin
                    // Logic handled in next_state
                end

                CHECK_Y: begin
                    // Logic handled in next_state
                end

                GCD_SETUP: begin
                    // Prepare GCD inputs
                    // Guard 1 (0, -A): line to (x, y). Vector (x, y - (-A)) = (x, y+A). Slope (y+A)/x.
                    // Condition: gcd(x, y+A) == 1
                    // Since y is signed, we cast y_reg to signed, add A (which is positive range limit, but input is A, range is -A to B)
                    // Wait, input A is the magnitude of the negative bound. Range is [-A, B].
                    // So Yg1 = -A. diff = y - (-A) = y + A.
                    // y_reg is signed. We need absolute value for distance? 
                    // The problem says gcd(x, |y - Yg|). 
                    // For Guard 1 (0, -A): |y - (-A)| = |y + A|. Since y >= -A, y+A >= 0.
                    // For Guard 2 (0, B): |y - B|. Since y <= B, B-y >= 0.
                    
                    gcd_a_in <= {16'b0, x_reg}; // Cast to 32-bit
                    
                    if (state == GCD_SETUP) begin
                         // We need a state to handle the two GCDs. 
                         // Let's handle Guard 1 first, then Guard 2 in next cycle.
                         // But the prompt says "fully pipelined". Let's process one x,y pair per iteration.
                         // We need to verify if we need strictly one cycle per (x,y).
                         // Euclidean algo takes multiple cycles.
                         // We need a flag to track which guard we are calculating.
                         // Let's add a guard_select register.
                    end
                end
            endcase
        end
    end

    // Re-structuring for Sequential Logic to handle two GCDs per (x,y) pair
    // We need internal flags to track GCD states
    reg guard_select; // 0: Guard 1, 1: Guard 2
    reg vis1, vis2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_reg <= 1;
            y_reg <= 0;
            ins_cnt <= 0;
            sec_cnt <= 0;
            sup_sec_cnt <= 0;
            done <= 0;
            insecure_count <= 0;
            secure_count <= 0;
            super_secure_count <= 0;
            
            guard_select <= 0;
            gcd_start <= 0;
            vis1 <= 0;
            vis2 <= 0;
            
            gcd_a_in <= 0;
            gcd_b_in <= 0;
        end else begin
            gcd_start <= 0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        x_reg <= 1;
                        y_reg <= -A;
                        ins_cnt <= 0;
                        sec_cnt <= 0;
                        sup_sec_cnt <= 0;
                        done <= 0;
                        vis1 <= 0;
                        vis2 <= 0;
                        guard_select <= 0;
                        state <= CHECK_X;
                    end
                end

                CHECK_X: begin
                    if ($signed(x_reg) > $signed(L)) begin
                        state <= DONE;
                        insecure_count <= ins_cnt;
                        secure_count <= sec_cnt;
                        super_secure_count <= sup_sec_cnt;
                    end else begin
                        state <= CHECK_Y;
                        y_reg <= -A;
                        vis1 <= 0;
                        vis2 <= 0;
                        guard_select <= 0;
                    end
                end

                CHECK_Y: begin
                    if ($signed(y_reg) > $signed(B)) begin
                        // y loop done, increment x
                        state <= INCR_X;
                    end else begin
                        // Start GCD for Guard 1
                        guard_select <= 0;
                        // Calculate |y - Yg|
                        // Guard 1 at -A: y - (-A) = y + A. Since y >= -A, this is non-negative.
                        // Guard 2 at B: |y - B| = B - y. Since y <= B, this is non-negative.
                        gcd_a_in <= {16'b0, x_reg}; // Cast x to 32-bit
                        gcd_b_in <= {21'b0, (y_reg + A)}; // Guard 1 val
                        
                        // Optimization: If x==1 or y_reg+A==1 or B-y==1, GCD is 1. 
                        // But let's use the GCD engine for simplicity and general case.
                        
                        // Start GCD
                        gcd_start <= 1;
                        state <= GCD_CALC;
                        
                        // Reset visibility bits for this pair
                        // Actually we need to keep them until both are done.
                        // Let's reset them before starting the loop (CHECK_Y), handle accumulation in CALCULATE.
                        // But we need to accumulate results for THIS pair.
                        // Let's use temporary flags temp_vis1, temp_vis2.
                    end
                end
                
                GCD_CALC: begin
                    if (gcd_active == 0 && gcd_valid) begin
                        // GCD Finished
                        if (guard_select == 0) begin
                            // Finished Guard 1
                            vis1 <= (gcd_result == 1);
                            // Start Guard 2
                            guard_select <= 1;
                            gcd_a_in <= {16'b0, x_reg};
                            gcd_b_in <= {21'b0, (B - y_reg)}; // Guard 2 val
                            gcd_start <= 1;
                        end else begin
                            // Finished Guard 2
                            vis2 <= (gcd_result == 1);
                            state <= CALCULATE;
                        end
                    end
                end

                CALCULATE: begin
                    // Update counters based on vis1 and vis2
                    if (vis1 == 0 && vis2 == 0) ins_cnt <= ins_cnt + 1;
                    else if (vis1 == 1 && vis2 == 1) sup_sec_cnt <= sup_sec_cnt + 1;
                    else sec_cnt <= sec_cnt + 1;
                    
                    // Next y
                    state <= CHECK_Y_INCR;
                end
                
                CHECK_Y_INCR: begin
                    y_reg <= y_reg + 1;
                    state <= CHECK_Y;
                    // Reset vis flags for next pair (optional, as we overwrite in CHECK_Y/GCD_SETUP)
                    // Actually CHECK_Y calculates GCD immediately, so we don't need to reset here if we set correctly in CHECK_Y
                end

                INCR_X: begin
                    x_reg <= x_reg + 1;
                    state <= CHECK_X;
                end

                DONE: begin
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule
