module gcd_sequence_checker (
    input clk,
    input rst_n,
    input start,
    input [2:0] k_in,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [7:0] x_in,
    input [7:0] m_limit,
    output reg found,
    output reg [7:0] j_out,
    output reg valid
);

    // Parameters
    parameter K = 8;
    parameter WIDTH = 8;

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers for state and control
    reg [1:0] state, next_state;
    reg [7:0] j_reg;           // Current start offset j
    reg [2:0] l_cnt;           // Current sequence index l
    reg [7:0] stored_x;        // Stored x_in during processing
    reg [7:0] stored_k;        // Stored k_in (cast to 8-bit for comparison)
    reg [7:0] a_reg [0:7];     // Stored sequence values
    
    // Combinational signals
    wire [7:0] gcd_val;
    wire gcd_match;
    wire [7:0] current_a;
    wire [7:0] arg_b;
    
    // GCD Combinational Logic (Subtraction Method for small values)
    // Since inputs are <= 255, subtraction converges quickly.
    // We use a combinational block to calculate GCD(x_in, j_reg + l_cnt)
    reg [7:0] gcd_a;
    reg [7:0] gcd_b;
    reg [7:0] gcd_res;
    
    assign gcd_val = gcd_res;

    always @(*) begin
        gcd_a = stored_x;
        gcd_b = j_reg + l_cnt;
        
        // Handle zero inputs if necessary (GCD(a, 0) = a)
        if (gcd_a == 8'b0) gcd_res = gcd_b;
        else if (gcd_b == 8'b0) gcd_res = gcd_a;
        else begin
            // Use a simplified iterative subtraction logic flattened for combinational path
            // Or use a helper loop. Given small width, a fully unrolled logic is okay.
            // However, for pure combinational without loops (better for synthesis predictability):
            // We will implement a small iterative state machine logic or just a loop if tool supports.
            // To ensure synthesizable combinational logic without loops, we can use a lookup table (LUT)
            // as suggested in the prompt, or a fixed logic chain.
            // Since values are 0-255, a pure combinational LUT is 256x256=65k entries. 
            // That is large but possible. Let's implement a small iterative subtraction logic inside an always block.
            // But wait, we cannot have loops in combinational logic without careful handling or `repeat`.
            // Let's implement a simple Euclidean algorithm using a loop inside an always @* block.
            // Most synthesis tools support `repeat` or fixed iteration counts for combinational logic.
            
            reg [7:0] u, v, tmp;
            u = gcd_a;
            v = gcd_b;
            // Fixed loop count is sufficient for 8-bit numbers (max 8 iterations ideally, but let's do 9 to be safe)
            repeat (9) begin
                if (u > v) begin
                    u = u - v;
                end else if (v > u) begin
                    v = v - u;
                end
            end
            gcd_res = u; // u and v are equal here (or one is 0)
        end
    end

    // Current sequence value selector
    assign current_a = a_reg[l_cnt];
    
    // Match condition
    assign gcd_match = (gcd_val == current_a);

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            found <= 1'b0;
            j_out <= 8'b0;
            valid <= 1'b0;
            j_reg <= 8'b0;
            l_cnt <= 3'b0;
            stored_x <= 8'b0;
            stored_k <= 8'b0;
            // Reset sequence array (optional but good practice)
            a_reg[0] <= 8'b0; a_reg[1] <= 8'b0; a_reg[2] <= 8'b0; a_reg[3] <= 8'b0;
            a_reg[4] <= 8'b0; a_reg[5] <= 8'b0; a_reg[6] <= 8'b0; a_reg[7] <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        // Load inputs
                        stored_x <= x_in;
                        stored_k <= {5'b0, k_in}; // Extend k_in to 8 bits for comparison
                        j_reg <= 8'b0;
                        l_cnt <= 3'b0;
                        // Load sequence array
                        a_reg[0] <= a_0;
                        a_reg[1] <= a_1;
                        a_reg[2] <= a_2;
                        a_reg[3] <= a_3;
                        a_reg[4] <= a_4;
                        a_reg[5] <= a_5;
                        a_reg[6] <= a_6;
                        a_reg[7] <= a_7;
                        found <= 1'b0;
                        j_out <= 8'b0;
                    end
                end

                PROCESSING: begin
                    // Check match for current j and l
                    if (gcd_match) begin
                        // Current element matches
                        if (l_cnt + 1 == stored_k) begin
                            // All elements matched for this j
                            found <= 1'b1;
                            j_out <= j_reg;
                            // Go to DONE handled in next_state logic
                        end else begin
                            // Continue checking next l for same j
                            l_cnt <= l_cnt + 1;
                        end
                    end else begin
                        // Mismatch for current j
                        // Need to move to next j
                        // Reset l_cnt and increment j
                        l_cnt <= 3'b0;
                        j_reg <= j_reg + 1;
                        // If j exceeds limit, we are done (handled in next_state)
                    end
                end

                DONE: begin
                    valid <= 1'b1;
                    // Wait for reset or new start
                    // If new start comes, IDLE state will handle loading
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
            end
            
            PROCESSING: begin
                // Logic to determine when to exit or transition
                // We need to check: if we just finished a sequence (found) -> DONE
                // If we mismatched and j exceeds limit -> DONE
                // If we mismatched and j within limit -> stay PROCESSING (and j incremented)
                // If we matched and not finished sequence -> stay PROCESSING

                if (gcd_match && (l_cnt + 1 == stored_k)) begin
                    // Just finished finding the sequence
                    next_state = DONE;
                end else if (!gcd_match) begin
                    // Mismatch, we are about to increment j in the sequential block
                    // But we must check if the incremented j exceeds limit
                    // Note: In sequential logic, we increment j_reg. Here we evaluate future state.
                    // Actually, it's cleaner to increment j in combinational block or check after increment.
                    // Let's check if (j_reg + 1 > m_limit)
                    if (j_reg + 1 > m_limit) begin
                        next_state = DONE;
                    end else begin
                        next_state = PROCESSING;
                    end
                end else begin
                    // Match but not finished sequence
                    next_state = PROCESSING;
                end
            end
            
            DONE: begin
                if (start) next_state = PROCESSING; // Restart on start
            end
        endcase
    end

endmodule