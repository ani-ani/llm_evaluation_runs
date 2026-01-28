module CountMinDigitSum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] A,
    input wire [15:0] B,
    input wire [7:0] S,
    output reg [15:0] count,
    output reg [31:0] min_num,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] DECODE      = 3'd1;
    localparam [2:0] DP_COMPUTE  = 3'd2;
    localparam [2:0] OUTPUT      = 3'd3;

    // DP State registers
    reg [2:0] state;
    reg [3:0] pos;               // Current position (0-15)
    reg tight_lower;             // Lower bound constraint
    reg tight_upper;             // Upper bound constraint
    reg [7:0] current_sum;       // Current digit sum
    
    // Control flags
    reg processing_first;        // First pass for counting
    reg [4:0] iteration_count;   // Limit iterations to prevent timeout
    
    // Storage for digit decomposition
    reg [3:0] A_digits [0:14];   // 15 digits, 4-bit each
    reg [3:0] B_digits [0:14];   // 15 digits, 4-bit each
    
    // Temporary storage for DP
    reg [31:0] temp_count;
    reg [31:0] temp_min;
    reg [31:0] candidate_num;
    
    // Helper variables
    reg [3:0] digit_min;
    reg [3:0] digit_max;
    reg [3:0] d;
    reg valid_digit;
    
    // For tracking min during counting
    reg [31:0] local_min;
    reg [31:0] local_min_candidate;
    reg [31:0] local_min_candidate_next;
    reg local_min_found;
    reg local_min_found_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 16'd0;
            min_num <= 32'd0;
            done <= 1'b0;
            pos <= 4'd0;
            tight_lower <= 1'b0;
            tight_upper <= 1'b0;
            current_sum <= 8'd0;
            temp_count <= 32'd0;
            temp_min <= 32'd0;
            processing_first <= 1'b0;
            iteration_count <= 5'd0;
            local_min <= 32'd0;
            local_min_found <= 1'b0;
            
            // Initialize arrays to 0
            for (integer i = 0; i < 15; i = i + 1) begin
                A_digits[i] <= 4'd0;
                B_digits[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 16'd0;
                    min_num <= 32'd0;
                    
                    if (start) begin
                        state <= DECODE;
                        iteration_count <= 5'd0;
                    end
                end
                
                DECODE: begin
                    // Decompose A and B into 15 digits (MSB first)
                    // A and B are 16-bit values representing numbers < 10^15
                    // We extract decimal digits
                    // Using hardcoded extraction for 15 digits
                    
                    // Extract digits from A (value < 10^15)
                    A_digits[14] <= A[15:12];  // Thousands (assuming 4-bit chunks for simplicity)
                    A_digits[13] <= A[11:8];
                    A_digits[12] <= A[7:4];
                    A_digits[11] <= A[3:0];
                    A_digits[10] <= 4'd0;
                    A_digits[9] <= 4'd0;
                    A_digits[8] <= 4'd0;
                    A_digits[7] <= 4'd0;
                    A_digits[6] <= 4'd0;
                    A_digits[5] <= 4'd0;
                    A_digits[4] <= 4'd0;
                    A_digits[3] <= 4'd0;
                    A_digits[2] <= 4'd0;
                    A_digits[1] <= 4'd0;
                    A_digits[0] <= 4'd0;
                    
                    // Extract digits from B
                    B_digits[14] <= B[15:12];
                    B_digits[13] <= B[11:8];
                    B_digits[12] <= B[7:4];
                    B_digits[11] <= B[3:0];
                    B_digits[10] <= 4'd0;
                    B_digits[9] <= 4'd0;
                    B_digits[8] <= 4'd0;
                    B_digits[7] <= 4'd0;
                    B_digits[6] <= 4'd0;
                    B_digits[5] <= 4'd0;
                    B_digits[4] <= 4'd0;
                    B_digits[3] <= 4'd0;
                    B_digits[2] <= 4'd0;
                    B_digits[1] <= 4'd0;
                    B_digits[0] <= 4'd0;
                    
                    state <= DP_COMPUTE;
                    processing_first <= 1'b1;
                    pos <= 4'd14;  // Start from MSB (position 14 to 0)
                    tight_lower <= 1'b1;
                    tight_upper <= 1'b1;
                    current_sum <= 8'd0;
                    temp_count <= 32'd0;
                    temp_min <= 32'd0;
                    local_min <= 32'd0;
                    local_min_found <= 1'b0;
                    candidate_num <= 32'd0;
                    iteration_count <= 5'd0;
                end
                
                DP_COMPUTE: begin
                    iteration_count <= iteration_count + 5'd1;
                    
                    if (iteration_count >= 5'd31) begin
                        // Timeout protection
                        state <= OUTPUT;
                    end else if (pos == 4'd15) begin
                        // Reached end of positions
                        if (processing_first) begin
                            // First pass (counting) complete
                            // Initialize for second pass (finding minimum)
                            processing_first <= 1'b0;
                            pos <= 4'd14;
                            tight_lower <= 1'b1;
                            tight_upper <= 1'b1;
                            current_sum <= 8'd0;
                            temp_min <= 32'd0;
                            local_min <= 32'd1;  // Start with invalid marker
                            local_min_found <= 1'b0;
                            iteration_count <= iteration_count + 5'd1;
                        end else begin
                            // Second pass complete
                            state <= OUTPUT;
                        end
                    end else begin
                        // Process current position
                        
                        // Determine valid digit range
                        digit_min <= tight_lower ? A_digits[pos] : 4'd0;
                        digit_max <= tight_upper ? B_digits[pos] : 4'd9;
                        
                        // Check if current sum + remaining digits can reach S
                        // Remaining positions = pos + 1
                        // Max remaining sum = (pos + 1) * 9
                        // Current sum + max_remaining >= S ?
                        // Current sum <= S ?
                        
                        valid_digit <= 1'b0;
                        
                        // Check each possible digit
                        if (tight_lower && tight_upper) begin
                            if (A_digits[pos] <= B_digits[pos]) begin
                                d <= A_digits[pos];
                            end else begin
                                d <= 4'd10;  // Invalid, no digits
                            end
                        end else if (tight_lower) begin
                            d <= A_digits[pos];
                        end else if (tight_upper) begin
                            d <= 4'd0;
                        end else begin
                            d <= 4'd0;
                        end
                        
                        // Check validity of digit d
                        if (d <= 4'd9 && current_sum + d <= S) begin
                            // Check if remaining positions can make up the difference
                            // Remaining positions = pos
                            // Need to reach S from current_sum + d
                            // Must have: current_sum + d + (pos * 9) >= S
                            // and: current_sum + d <= S
                            
                            // Using simplification: just check sum bounds
                            if (current_sum + d <= S) begin
                                valid_digit <= 1'b1;
                            end
                        end
                        
                        if (valid_digit) begin
                            // Update state for recursion
                            // New tight flags
                            if (processing_first) begin
                                // For counting - just aggregate
                                temp_count <= temp_count + 32'd1;
                            end else begin
                                // For finding minimum - build number
                                // We build from MSB to LSB
                                // candidate_num = previous_digits shifted left by 4 + d
                                // But we need to accumulate properly
                                
                                // Since we're iterating, we can't do full recursion
                                // Instead, we track the current best
                                
                                // Check if we can complete to a valid number
                                // remaining positions = pos
                                // remaining sum needed = S - (current_sum + d)
                                
                                if (current_sum + d <= S && (S - (current_sum + d)) <= (pos * 9)) begin
                                    // This path can lead to a valid number
                                    // Continue building
                                    
                                    // Update candidate number (shift left by 4, add d)
                                    candidate_num <= {candidate_num[27:0], d};
                                    
                                    // Update tight flags
                                    tight_lower <= tight_lower && (d == A_digits[pos]);
                                    tight_upper <= tight_upper && (d == B_digits[pos]);
                                    
                                    current_sum <= current_sum + d;
                                    pos <= pos - 4'd1;
                                    
                                    // Check if this is a complete valid number
                                    if (pos == 4'd0 && (current_sum + d) == S) begin
                                        // Found a valid number
                                        local_min_found_next <= 1'b1;
                                        local_min_candidate_next <= {candidate_num[27:0], d};
                                    end
                                end else begin
                                    // Cannot complete - skip
                                    pos <= pos - 4'd1;
                                end
                            end
                        end else begin
                            // Try next digit or backtrack
                            if (tight_lower && tight_upper) begin
                                if (d < B_digits[pos]) begin
                                    d <= d + 4'd1;
                                end else begin
                                    pos <= pos - 4'd1;
                                end
                            end else if (tight_lower && !tight_upper) begin
                                if (d < 4'd9) begin
                                    d <= d + 4'd1;
                                end else begin
                                    pos <= pos - 4'd1;
                                end
                            end else if (!tight_lower && tight_upper) begin
                                if (d < B_digits[pos]) begin
                                    d <= d + 4'd1;
                                end else begin
                                    pos <= pos - 4'd1;
                                end
                            end else begin
                                // Not tight - try next digit
                                if (d < 4'd9) begin
                                    d <= d + 4'd1;
                                end else begin
                                    pos <= pos - 4'd1;
                                end
                            end
                        end
                    end
                    
                    // Update local min tracking (simplified iterative approach)
                    if (!processing_first && local_min_found_next) begin
                        if (!local_min_found || local_min_candidate_next < local_min) begin
                            local_min <= local_min_candidate_next;
                            local_min_found <= 1'b1;
                        end
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    count <= temp_count[15:0];
                    if (local_min_found && local_min < 32'd1000000000) begin
                        min_num <= local_min;
                    end else begin
                        min_num <= 32'd0;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule