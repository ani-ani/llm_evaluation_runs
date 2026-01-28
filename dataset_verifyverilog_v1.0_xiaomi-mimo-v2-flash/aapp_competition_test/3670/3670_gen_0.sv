module find_modulus(
    input clk,
    input rst_n,
    input start,
    input [79:0] num_data,  // 8 x 10-bit packed
    input [3:0] N,
    output reg [9:0] result_M,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] S0   = 3'd1;  // Compute differences
    localparam [2:0] S1   = 3'd2;  // Compute GCD
    localparam [2:0] S2   = 3'd3;  // Enumerate divisors
    localparam [2:0] S3   = 3'd4;  // Output valid
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [9:0] nums [0:7];  // Unpacked 10-bit array for numbers
    reg [10:0] diffs [0:27];  // Unpacked 11-bit array for differences (max 28)
    reg [9:0] g;  // GCD result (max 1024)
    reg [9:0] divisor;  // Current divisor candidate
    reg [5:0] diff_idx;  // Index for diff array (0-27)
    reg [3:0] i, j;  // Pair indices
    reg [1:0] gcd_stage;  // For GCD computation
    reg [9:0] a_reg, b_reg;  // For GCD
    reg [9:0] temp_val;  // Temporary for GCD
    reg [3:0] valid_count;  // Count of valid diffs
    reg [10:0] max_diff;  // Store max difference
    reg [9:0] gcd_divisor_temp;  // For divisor check
    
    // Loop counters
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_M <= 10'd0;
            valid <= 1'b0;
            done <= 1'b0;
            // Initialize all arrays
            for (k = 0; k < 8; k = k + 1) begin
                nums[k] <= 10'd0;
            end
            for (k = 0; k < 28; k = k + 1) begin
                diffs[k] <= 11'd0;
            end
            g <= 10'd0;
            divisor <= 10'd0;
            diff_idx <= 6'd0;
            i <= 4'd0;
            j <= 4'd0;
            gcd_stage <= 2'd0;
            a_reg <= 10'd0;
            b_reg <= 10'd0;
            temp_val <= 10'd0;
            valid_count <= 4'd0;
            max_diff <= 11'd0;
            gcd_divisor_temp <= 10'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    result_M <= 10'd0;
                    if (start) begin
                        // Unpack numbers and scale down
                        nums[0] <= num_data[9:0];
                        nums[1] <= num_data[19:10];
                        nums[2] <= num_data[29:20];
                        nums[3] <= num_data[39:30];
                        nums[4] <= num_data[49:40];
                        nums[5] <= num_data[59:50];
                        nums[6] <= num_data[69:60];
                        nums[7] <= num_data[79:70];
                        diff_idx <= 6'd0;
                        i <= 4'd0;
                        j <= 4'd1;
                        valid_count <= 4'd0;
                        max_diff <= 11'd0;
                    end
                end

                S0: begin  // Compute differences
                    if (i < N && j < N) begin
                        // Calculate absolute difference
                        if (nums[i] > nums[j]) begin
                            diffs[diff_idx] <= nums[i] - nums[j];
                        end else begin
                            diffs[diff_idx] <= nums[j] - nums[i];
                        end
                        
                        // Update max diff
                        if (diff_idx > 0) begin
                            if (diffs[diff_idx] > max_diff) begin
                                max_diff <= diffs[diff_idx];
                            end
                        end else begin
                            max_diff <= diffs[diff_idx];
                        end
                        
                        diff_idx <= diff_idx + 6'd1;
                        valid_count <= valid_count + 4'd1;
                        j <= j + 4'd1;
                    end else if (i < N) begin
                        i <= i + 4'd1;
                        j <= i + 4'd2;
                    end
                end

                S1: begin  // Compute GCD
                    case (gcd_stage)
                        2'd0: begin
                            // Find first non-zero diff
                            if (diff_idx < 28) begin
                                if (diffs[diff_idx] != 11'd0) begin
                                    a_reg <= diffs[diff_idx][9:0];
                                    b_reg <= max_diff[9:0];
                                    gcd_stage <= 2'd1;
                                end
                                diff_idx <= diff_idx + 6'd1;
                            end else begin
                                g <= max_diff[9:0];
                                gcd_stage <= 2'd0;
                            end
                        end
                        2'd1: begin  // Binary GCD
                            if (a_reg == 10'd0) begin
                                g <= b_reg;
                                gcd_stage <= 2'd2;
                            end else if (b_reg == 10'd0) begin
                                g <= a_reg;
                                gcd_stage <= 2'd2;
                            end else if (a_reg[0] == 1'b0 && b_reg[0] == 1'b0) begin
                                a_reg <= {1'b0, a_reg[9:1]};
                                b_reg <= {1'b0, b_reg[9:1]};
                            end else if (a_reg[0] == 1'b0) begin
                                a_reg <= {1'b0, a_reg[9:1]};
                            end else if (b_reg[0] == 1'b0) begin
                                b_reg <= {1'b0, b_reg[9:1]};
                            end else begin
                                if (a_reg > b_reg) begin
                                    a_reg <= a_reg - b_reg;
                                end else begin
                                    b_reg <= b_reg - a_reg;
                                end
                            end
                        end
                        2'd2: begin  // Check next diff
                            if (diff_idx < 28) begin
                                if (diffs[diff_idx] != 11'd0) begin
                                    a_reg <= diffs[diff_idx][9:0];
                                    b_reg <= g;
                                    gcd_stage <= 2'd1;
                                end
                                diff_idx <= diff_idx + 6'd1;
                            end else begin
                                gcd_stage <= 2'd0;
                            end
                        end
                    endcase
                end

                S2: begin  // Enumerate divisors
                    // Reset divisor to start at 2
                    divisor <= divisor + 10'd1;
                    if (divisor < g) begin
                        // Check if divisor divides g
                        if (g % divisor == 10'd0) begin
                            result_M <= divisor;
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                    end
                end

                S3: begin  // Output valid divisors (single cycle per divisor)
                    // Transition to next divisor
                    valid <= 1'b0;
                    divisor <= divisor + 10'd1;
                    if (divisor < g) begin
                        if (g % divisor == 10'd0) begin
                            result_M <= divisor;
                            valid <= 1'b1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    result_M <= 10'd0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (N <= 4'd1) begin
                        next_state = FINISH;  // Need at least 2 numbers
                    end else begin
                        next_state = S0;
                    end
                end
            end
            
            S0: begin
                // Wait for all pairs (i<N and j<N)
                if (i >= N) begin
                    // Check if any valid differences found
                    if (valid_count > 4'd0) begin
                        next_state = S1;
                    end else begin
                        next_state = FINISH;
                    end
                end
            end
            
            S1: begin
                // Wait for GCD computation
                if (gcd_stage == 2'd2 && diff_idx >= 28) begin
                    if (g > 10'd1) begin
                        next_state = S2;
                        divisor <= 10'd2;  // Start from 2
                    end else begin
                        next_state = FINISH;
                    end
                end
            end
            
            S2: begin
                // Check first divisor (2)
                if (divisor < g) begin
                    next_state = S3;
                end else begin
                    next_state = FINISH;
                end
            end
            
            S3: begin
                // Continue checking divisors
                if (divisor < g) begin
                    next_state = S3;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule