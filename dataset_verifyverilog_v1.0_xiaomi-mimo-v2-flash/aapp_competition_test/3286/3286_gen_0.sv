module robber_language (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] len,
    input wire [127:0] str,
    output reg [23:0] result,
    output reg done
);

    // Modulus constant
    localparam [23:0] MOD = 24'd1000009;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LEN = 3'd1;
    localparam [2:0] DP_LOOP = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] i; // Iteration index for DP (0 to len)
    reg [4:0] idx; // Character index in string (0 to len-1)
    reg [23:0] dp_count; // Stores count for current position i
    reg [23:0] next_dp_count; // Next value for dp_count
    reg [23:0] temp_result;
    reg char_is_vowel;
    reg [7:0] current_char;
    reg [7:0] char_o;

    // Helper logic to check vowel
    always @(*) begin
        char_is_vowel = 1'b0;
        current_char = str[ (idx * 8) +: 8 ];
        char_o = 8'b01101111; // ASCII 'o'

        case (current_char)
            8'h61, 8'h65, 8'h69, 8'h6F, 8'h75: begin // a, e, i, o, u
                char_is_vowel = 1'b1;
            end
            default: char_is_vowel = 1'b0;
        endcase
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        next_dp_count = dp_count;
        temp_result = result;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_LEN;
                end
            end

            CHECK_LEN: begin
                if (len == 5'd0) begin
                    next_state = FINISH;
                end else begin
                    // Initialize DP: dp[0] = 1
                    next_dp_count = 24'd1;
                    i = 5'd1; // Start processing for i=1 (first char)
                    next_state = DP_LOOP;
                end
            end

            DP_LOOP: begin
                if (i > len) begin
                    // Done with DP loop, move to finish
                    next_state = FINISH;
                end else begin
                    // i corresponds to the length of the prefix processed (1-based)
                    // We look at the character at index i-1
                    if (char_is_vowel) begin
                        // Vowel: previous state must have had length i-1
                        // dp[i] = dp[i-1]
                        next_dp_count = temp_result;
                        next_state = DP_LOOP;
                    end else begin
                        // Consonant: compute next state
                        // dp[i] = dp[i-1] + dp[i-3] (if valid)
                        // We will compute this in next state
                        next_state = DP_COMPUTE;
                    end
                end
            end

            DP_COMPUTE: begin
                // We are at index 'i' (1-based), looking at char at 'i-1'
                // dp[i] = dp[i-1] + (i>=3 ? dp[i-3] : 0)
                temp_result = temp_result;
                if (i >= 3) begin
                    // Need to read dp[i-3]. 
                    // Since we only store current dp_count, we'd need history.
                    // Given constraints, let's use a lookup array for DP values.
                    // Re-evaluating design: Use small DP array for safety.
                end
                next_state = DP_LOOP;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            dp_count <= 24'd0;
            i <= 5'd0;
            idx <= 5'd0;
        end else begin
            done <= 1'b0;
            state <= next_state;
            dp_count <= next_dp_count;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        result <= 24'd1; // Initialize DP[0] = 1
                    end
                end
                CHECK_LEN: begin
                    if (len != 5'd0) begin
                        // Reset loop vars
                        i <= 5'd1;
                        // idx is index in str. For i=1, idx=0
                        idx <= 5'd0;
                    end
                end
                DP_LOOP: begin
                    if (i <= len) begin
                        // Process char at idx (i-1)
                        if (char_is_vowel) begin
                            // dp[i] = dp[i-1]
                            // result currently holds dp[i-1]
                            // So result remains same
                            // result <= result; 
                        end else begin
                            // Consonant: dp[i] = dp[i-1] + dp[i-3]
                            // We need dp[i-3]. 
                            // Let's use a small history array to keep it valid.
                            // BUT, to keep it simple and stateless (mostly):
                            // We can rely on the fact that we only need to look back.
                            // Let's use a fixed size array for DP values since N is small.
                            // 17 entries * 24 bits = 408 bits. Trivial.
                            
                            // If we use array, we update it in the loop.
                            // Let's refine the DP logic to use an array.
                        end
                        
                        i <= i + 5'd1;
                        idx <= idx + 5'd1;
                    end
                end
                FINISH: begin
                    // Ensure result is modulo
                    // result <= result % MOD; 
                    // Since we mod on every add, it should be fine.
                    done <= 1'b1;
                end
            endcase
        end
    end

    // --- RE-WRITTEN LOGIC WITH ARRAY FOR CORRECTNESS ---
    // The previous logic had issues with looking back dp[i-3] without history.
    // Using a proper DP array implementation.

    reg [23:0] dp [0:16]; // DP array
    reg [4:0] k; // Loop variable
    reg [23:0] val1, val2;
    
    // Combinational logic for next state and next DP values
    always @(*) begin
        next_state = state;
        char_is_vowel = 1'b0;
        current_char = str[ (k * 8) +: 8 ];
        
        // Check vowel
        case (current_char)
            8'h61, 8'h65, 8'h69, 8'h6F, 8'h75: char_is_vowel = 1'b1;
            default: char_is_vowel = 1'b0;
        endcase

        case (state)
            IDLE: begin
                if (start) next_state = CHECK_LEN;
            end
            
            CHECK_LEN: begin
                // If len is 0, result is 1 (empty string), done immediately
                if (len == 5'd0) next_state = FINISH;
                else next_state = DP_LOOP_INIT;
            end

            DP_LOOP_INIT: begin
                // Initialize dp[0] = 1
                // Handled in sequential logic
                next_state = DP_LOOP;
            end

            DP_LOOP: begin
                // Loop k from 1 to len
                if (k > len) begin
                    next_state = FINISH;
                end else begin
                    next_state = DP_COMPUTE;
                end
            end

            DP_COMPUTE: begin
                // Calculate dp[k]
                // dp[k] = dp[k-1] if vowel
                // dp[k] = dp[k-1] + dp[k-3] if consonant (and k>=3)
                // dp[k] = dp[k-1] if consonant (and k<3)
                
                // We need to read dp[k-1] and dp[k-3] from the array
                // These are available in 'dp' array from previous iterations
                // Access is combinational based on k
                
                // Update dp[k] logic (combinational result)
                // Note: Sequential block will write this to dp[k]
                next_state = DP_LOOP;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic with Array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            k <= 5'd0;
            // Initialize array to 0
            for (int idx_rst = 0; idx_rst <= 16; idx_rst = idx_rst + 1) begin
                dp[idx_rst] <= 24'd0;
            end
        end else begin
            done <= 1'b0;
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset loop var
                        k <= 5'd1;
                        // Clear array (partially, to be safe)
                        for (int i = 0; i <= 16; i = i + 1) dp[i] <= 24'd0;
                    end
                end

                CHECK_LEN: begin
                    // Just transition, maybe pre-check len
                end

                DP_LOOP_INIT: begin
                    dp[0] <= 24'd1;
                    k <= 5'd1;
                end

                DP_LOOP: begin
                    if (k > len) begin
                        // Fall through to finish
                    end else begin
                        // Transition to compute
                        // We pass k to compute logic implicitly
                    end
                end

                DP_COMPUTE: begin
                    // Perform calculation based on char at k-1
                    // current_char is derived from k-1 in combo logic, 
                    // but we need to latch it or ensure stability.
                    // Since k increments in DP_LOOP, we can use (k-1) here if we are careful.
                    // Wait, if we are in DP_COMPUTE, we just came from DP_LOOP where k was correct.
                    // So current_char is based on (k-1).
                    
                    if (char_is_vowel) begin
                        dp[k] <= dp[k-1];
                    end else begin
                        // Consonant
                        if (k >= 3) begin
                            // Add dp[k-1] and dp[k-3]
                            // Do modulo arithmetic
                            dp[k] <= (dp[k-1] + dp[k-3]) % MOD;
                        end else begin
                            // k is 1 or 2. Cannot look back 3.
                            // dp[k] = dp[k-1]
                            dp[k] <= dp[k-1];
                        end
                    end
                    
                    k <= k + 5'd1;
                end

                FINISH: begin
                    if (len == 5'd0) result <= 24'd1;
                    else result <= dp[len];
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule