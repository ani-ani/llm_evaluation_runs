module RemaindersSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [19:0] k,
    input wire c_valid,
    input wire [19:0] c_in,
    output reg result,
    output reg done,
    output reg ready
);

    // FSM States
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] LOAD  = 3'd1;
    localparam [2:0] GCD_1 = 3'd2;
    localparam [2:0] LCM_1 = 3'd3;
    localparam [2:0] CALC  = 3'd4;
    localparam [2:0] DONE  = 3'd5;

    reg [2:0] state, next_state;

    // Internal Registers
    reg [19:0] lcm_acc;
    reg [3:0]  counter;
    reg [19:0] g_val;          // Stores gcd(k, c_in)
    reg [19:0] l_val;          // Stores lcm_acc before update
    reg [19:0] b_val;          // Stores g to compute lcm(lcm_acc, g)
    
    // GCD Computation Registers
    reg [19:0] gcd_a;
    reg [19:0] gcd_b;
    wire gcd_done;
    wire [19:0] gcd_result;

    // GCD Sub-module (Iterative Euclidean Algorithm)
    // Runs in 2-3 cycles max for 20-bit numbers
    gcd_unit gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start((state == GCD_1) && (next_state == GCD_1)), // Trigger based on transition
        .a(gcd_a),
        .b(gcd_b),
        .result(gcd_result),
        .done(gcd_done)
    );

    // Control Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            lcm_acc <= 20'd1;
            counter <= 4'd0;
            g_val <= 20'd0;
            l_val <= 20'd0;
            b_val <= 20'd0;
            result <= 1'b0;
            done <= 1'b0;
            ready <= 1'b0;
        end else begin
            done <= 1'b0; // Pulse reset
            
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    lcm_acc <= 20'd1;
                    counter <= 4'd0;
                    if (start) begin
                        state <= LOAD;
                        ready <= 1'b1;
                    end
                end

                LOAD: begin
                    if (c_valid) begin
                        // Compute gcd(k, c_in)
                        // k is fixed, c_in is stream
                        // Handle edge case c_in == 0 (should be coprime -> gcd=1)
                        if (c_in == 20'd0) begin
                            g_val <= 20'd1;
                            state <= LCM_1;
                            ready <= 1'b0; // Pause ready during calc
                        end else begin
                            gcd_a <= k;
                            gcd_b <= c_in;
                            state <= GCD_1;
                            ready <= 1'b0; // Pause ready during calc
                        end
                        counter <= counter + 4'd1;
                    end
                    
                    if (counter == n) begin
                        // All inputs processed, move to final calc
                        if (ready) begin // Only if not currently processing
                            state <= CALC;
                            ready <= 1'b0;
                        end
                    end
                end

                GCD_1: begin
                    // Wait for GCD result
                    if (gcd_done) begin
                        g_val <= gcd_result;
                        state <= LCM_1;
                    end
                end

                LCM_1: begin
                    // Update lcm_acc = lcm(lcm_acc, g_val)
                    // Formula: (a * b) / gcd(a, b)
                    // Here: (lcm_acc * g_val) / g_val  (since g_val is already gcd)
                    // Wait, we need to compute lcm(lcm_acc, g_val).
                    // We need gcd(lcm_acc, g_val). But g_val divides k, and lcm_acc divides k.
                    // The gcd of two divisors of k is also a divisor of k.
                    // We reuse the GCD unit for (lcm_acc, g_val).
                    
                    // Optimization: If g_val divides lcm_acc, lcm_acc stays same.
                    // Since lcm_acc is a multiple of previous gcds, and g_val is gcd(k, c_i),
                    // g_val might divide lcm_acc. Check (lcm_acc % g_val == 0).
                    // However, adding a divider is expensive. We will just run GCD.
                    
                    // Note: We need to compute gcd(lcm_acc, g_val) first.
                    // Transition to GCD state again.
                    gcd_a <= lcm_acc;
                    gcd_b <= g_val;
                    state <= GCD_1; // Re-enter GCD state
                    // We need a way to distinguish which GCD calculation we are in.
                    // Using a flag or simple path logic.
                    // Let's use a temporary flag or simpler state structure.
                    // Actually, let's just add a few states for clarity.
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Additional logic to handle the two-phase GCD (LOAD phase and LCM phase)
    // We need to differentiate the GCD target.
    // Let's modify the FSM slightly to have distinct states for GCD computations.

    // Revised FSM Logic for LCM update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            // LCM update logic specific to LCM_1 state
            if (state == LCM_1 && gcd_done) begin
                // We just computed gcd(lcm_acc, g_val) which is in gcd_result.
                // lcm = (lcm_acc * g_val) / gcd(lcm_acc, g_val)
                // Since lcm_acc <= k and g_val <= k, product fits in 40 bits.
                // We can compute the division only if the result fits in 20 bits.
                // Since the result MUST divide k (<= 20 bits), it will fit.
                
                // To avoid overflow, we can check divisibility first or use wide registers.
                // Using 40-bit register for intermediate product.
                wire [39:0] product;
                assign product = lcm_acc * g_val;
                
                // Division by gcd_result
                // Since product = lcm_acc * g_val, and gcd_result divides both,
                // the division is exact.
                if (gcd_result != 20'd0) begin
                    lcm_acc <= product / gcd_result;
                end
                
                // Resume LOAD state or finish
                if (counter < n) begin
                    state <= LOAD;
                    ready <= 1'b1;
                end else begin
                    state <= CALC;
                end
            end
        end
    end

    // Final Calculation and Result Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == CALC) begin
                result <= (lcm_acc == k);
                state <= DONE;
            end
            
            if (state == DONE) begin
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end

endmodule

// GCD Submodule (Iterative)
module gcd_unit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] a,
    input wire [19:0] b,
    output reg [19:0] result,
    output reg done
);
    reg [19:0] x, y;
    reg running;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running <= 1'b0;
            done <= 1'b0;
            result <= 20'd1;
        end else begin
            done <= 1'b0;
            
            if (start && !running) begin
                x <= (a == 20'd0) ? 20'd1 : a; // Handle 0 input
                y <= (b == 20'd0) ? 20'd1 : b;
                running <= 1'b1;
            end else if (running) begin
                if (y == 20'd0) begin
                    result <= x;
                    done <= 1'b1;
                    running <= 1'b0;
                end else begin
                    x <= y;
                    y <= x % y;
                end
            end
        end
    end
endmodule