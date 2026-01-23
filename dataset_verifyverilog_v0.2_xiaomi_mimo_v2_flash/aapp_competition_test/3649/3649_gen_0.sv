module bitstring_constructor (
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [31:0] b,
    input [31:0] c,
    input [31:0] d,
    output reg [7:0] result_string,
    output reg [2:0] result_length,
    output reg done,
    output reg valid
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK_PARAMS = 3'b001;
    localparam SOLVE_KL = 3'b010;
    localparam CONSTRUCT = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    
    // Internal registers for calculation
    reg [31:0] k, l;
    reg [31:0] k_sq, l_sq;
    reg [31:0] cnt;
    reg [31:0] temp_val;
    
    // Registers for construction
    reg [7:0] working_string;
    reg [2:0] len;
    reg [2:0] bit_idx;
    reg found_sol;
    reg temp_valid;
    
    // Temp calculations for sqrt
    reg [31:0] sqrt_term;
    reg [31:0] sqrt_val;
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_PARAMS;
            end
            CHECK_PARAMS: begin
                next_state = SOLVE_KL;
            end
            SOLVE_KL: begin
                // Wait for calculation steps
                if (cnt >= 5) next_state = CONSTRUCT;
            end
            CONSTRUCT: begin
                // 8 cycles to build string
                if (bit_idx >= 4'd8 || (len >= k + l && k + l <= 8) || (len >= 8)) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_string <= 8'h00;
            result_length <= 3'b000;
            done <= 1'b0;
            valid <= 1'b0;
            k <= 32'b0;
            l <= 32'b0;
            cnt <= 32'b0;
            bit_idx <= 4'd0;
            len <= 3'b0;
            working_string <= 8'h00;
            found_sol <= 1'b0;
            temp_valid <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    result_length <= 3'b000;
                    result_string <= 8'h00;
                    cnt <= 32'b0;
                    bit_idx <= 4'd0;
                    len <= 3'b0;
                    found_sol <= 1'b0;
                    temp_valid <= 1'b0;
                    // Start detection is handled in transition
                end
                
                CHECK_PARAMS: begin
                    // Verify b == c
                    if (b != c) begin
                        // Transition directly to DONE with invalid
                        done <= 1'b1;
                        valid <= 1'b0;
                        state <= DONE;
                    end else begin
                        // Initialize calculation
                        cnt <= 32'b0;
                        k <= 32'b0;
                        l <= 32'b0;
                    end
                end
                
                SOLVE_KL: begin
                    // Compute k = (1 + sqrt(1 + 8*a)) / 2
                    // Compute l = (1 + sqrt(1 + 8*d)) / 2
                    // Pipeline stages
                    cnt <= cnt + 1;
                    
                    case (cnt)
                        0: begin // Compute 8*a
                            if (a == 0) k <= 0;
                            else if (a >= 32'h20000000) k <= 0; // Overflow protection
                            else temp_val <= a << 3;
                        end
                        1: begin // Compute 1+8*a
                            if (a == 0) k <= 0;
                            else temp_val <= temp_val + 1;
                        end
                        2: begin // Sqrt approximation (linear search)
                            // Check small values first
                            if (a == 0) begin
                                k <= 0;
                            end else if (a == 1) begin
                                k <= 2; // (1+3)/2 = 2
                            end else begin
                                // Start search
                                sqrt_term <= temp_val;
                                sqrt_val <= 0;
                            end
                        end
                        3: begin // Sqrt loop execution part 1 (bitwise or simple increment)
                            // Simple iterative sqrt for small values
                            if (a > 0 && sqrt_term > 0) begin
                                // Optimized for constraint: if 1+8a is perfect square
                                // Check if (2k-1)^2 = 1+8a
                                // We scan k from 0 to 128 (since max length 8, k <= 8)
                                // Actually, let's use the formula derived from max length 8
                                // k <= 8, l <= 8. So max valid input is small.
                                // Let's verify existence:
                                // k satisfies k*(k-1) == 2a
                                // Iterate k from 0 to 8
                                if (k < 8 && k*(k-1)/2 != a) begin
                                    k <= k + 1;
                                end
                            end
                        end
                        4: begin // Compute L similar to K
                             // Logic for L
                             if (d == 0) l <= 0;
                             else if (d == 1) l <= 2;
                             else begin
                                if (l < 8 && l*(l-1)/2 != d) begin
                                    l <= l + 1;
                                end
                             end
                        end
                        5: begin // Final Verification
                            // Check if (k*(k-1)/2 == a) AND (l*(l-1)/2 == d) AND (k*l == b)
                            // If yes, found_sol = 1
                            if ((k*(k-1)/2 == a || (a==0 && (k==0 || k==1))) && 
                                (l*(l-1)/2 == d || (d==0 && (l==0 || l==1))) && 
                                (k*l == b)) begin
                                found_sol <= 1'b1;
                                temp_valid <= 1'b1;
                            end else begin
                                found_sol <= 1'b0;
                                temp_valid <= 1'b0;
                            end
                        end
                    endcase
                end
                
                CONSTRUCT: begin
                    bit_idx <= bit_idx + 1;
                    
                    if (found_sol && temp_valid && (k + l <= 8)) begin
                        // Construction Logic
                        // Rules:
                        // 1. If b >= k and (b-k)%(k-1)==0 and k>1: 0s, 0, 1s
                        // 2. Else if c >= k and (c-k)%(l-1)==0 and l>1: 1, 0s, 1s
                        // 3. Else all 0s then 1s
                        
                        // We build bit by bit. 
                        // Let's map the bit index to the pattern
                        
                        // Handle edge cases where k or l is 0 or 1
                        
                        // Pattern 1: Zeros (k-1), then '0', then L ones
                        // Pattern 2: '1', then K zeros, then (l-1) ones
                        // Pattern 3: K zeros, then L ones
                        
                        // Determine pattern once
                        // We use bit_idx to track progress
                        
                        // Since we are in a sequential block, we can use if/else based on current state of construction
                        // We need to check conditions again inside or store the pattern decision
                        // Let's store decision in a reg
                        
                        // Determine pattern on first cycle of CONSTRUCT
                        if (bit_idx == 0) begin
                            if (k > 1 && b >= k && ((b - k) % (k - 1) == 0)) begin
                                // Pattern A
                                // 0..0 (k-1), 0, 1..1 (l)
                                // Let's use a mode register
                                // 00: Default (K zeros, L ones)
                                // 01: Pattern A
                                // 10: Pattern B
                                // 11: Pattern C (already handled by default or separate)
                                // We can reuse found_sol as a flag, but let's be clean
                                // We'll use 'temp_val' to store mode
                                // Mode 1: Pattern A
                                temp_val <= 1;
                            end else if (l > 1 && c >= k && ((c - k) % (l - 1) == 0)) begin
                                // Pattern B
                                temp_val <= 2;
                            end else begin
                                // Pattern 3 (Default)
                                temp_val <= 3;
                            end
                        end else begin
                            // Append bits based on mode
                            case (temp_val)
                                1: begin // Pattern A: (k-1) zeros, then 0, then l ones
                                    if (len < k - 1) begin
                                        working_string <= {working_string[6:0], 1'b0};
                                        len <= len + 1;
                                    end else if (len == k - 1) begin
                                        working_string <= {working_string[6:0], 1'b0}; // The required 0 in middle
                                        len <= len + 1;
                                    end else if (len < k + l) begin
                                        working_string <= {working_string[6:0], 1'b1};
                                        len <= len + 1;
                                    end
                                end
                                2: begin // Pattern B: 1, then k zeros, then (l-1) ones
                                    if (len == 0) begin
                                        working_string <= {working_string[6:0], 1'b1};
                                        len <= len + 1;
                                    end else if (len <= k) begin // k zeros after the first 1 (indices 1 to k)
                                        working_string <= {working_string[6:0], 1'b0};
                                        len <= len + 1;
                                    end else if (len < k + l) begin
                                        working_string <= {working_string[6:0], 1'b1};
                                        len <= len + 1;
                                    end
                                end
                                3: begin // Pattern 3: K zeros then L ones
                                    if (len < k) begin
                                        working_string <= {working_string[6:0], 1'b0};
                                        len <= len + 1;
                                    end else if (len < k + l) begin
                                        working_string <= {working_string[6:0], 1'b1};
                                        len <= len + 1;
                                    end
                                end
                            endcase
                        end
                    end else if (found_sol && temp_valid && (k + l > 8)) begin
                        // Cap at 8
                        // Just fill with 0s to prevent garbage or fill based on partial?
                        // 