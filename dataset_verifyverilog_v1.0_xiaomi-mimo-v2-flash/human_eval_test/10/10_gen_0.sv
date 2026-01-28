module shortest_palindrome(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][7:0] input_str,
    input wire [4:0] input_len,
    output reg [31:0][7:0] output_str,
    output reg [5:0] output_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_PALIN   = 3'd1;
    localparam [2:0] FIND_SUFFIX   = 3'd2;
    localparam [2:0] BUILD_OUTPUT  = 3'd3;
    localparam [2:0] FINISH        = 3'd4;
    
    reg [2:0] state, next_state;
    reg [5:0] cycle_count;  // Max 128 cycles
    localparam [5:0] MAX_CYCLES = 6'd128;
    
    // Internal registers for computation
    reg [4:0] i, j;  // Loop counters (0-15)
    reg [4:0] len_k;  // Length of longest palindromic suffix
    reg [31:0][7:0] temp_output;
    reg [5:0] temp_len;
    reg is_palindrome;
    reg [4:0] suffix_len;
    reg [4:0] suffix_start;
    reg [4:0] compare_idx;
    reg [4:0] compare_end;
    reg mismatch;
    reg [4:0] prefix_len;
    reg [4:0] build_idx;
    reg [4:0] build_idx2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            cycle_count <= 6'd0;
            i <= 5'd0;
            j <= 5'd0;
            len_k <= 5'd0;
            is_palindrome <= 1'b0;
            suffix_len <= 5'd0;
            suffix_start <= 5'd0;
            compare_idx <= 5'd0;
            compare_end <= 5'd0;
            mismatch <= 1'b0;
            prefix_len <= 5'd0;
            build_idx <= 5'd0;
            build_idx2 <= 5'd0;
            output_len <= 6'd0;
            done <= 1'b0;
            // Initialize output_str array
            for (int idx = 0; idx < 32; idx = idx + 1) begin
                output_str[idx] <= 8'd0;
            end
            // Initialize temp_output array
            for (int idx = 0; idx < 32; idx = idx + 1) begin
                temp_output[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        if (input_len == 5'd0) begin
                            // Empty string: output empty
                            output_len <= 6'd0;
                            for (int idx = 0; idx < 32; idx = idx + 1) begin
                                output_str[idx] <= 8'd0;
                            end
                            state <= FINISH;
                        end else begin
                            state <= CHECK_PALIN;
                            i <= 5'd0;
                            is_palindrome <= 1'b1;
                        end
                    end
                end
                
                CHECK_PALIN: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Compare input_str[i] with input_str[input_len-1-i]
                    if (i < input_len) begin
                        if (input_str[i] != input_str[input_len - 1 - i]) begin
                            is_palindrome <= 1'b0;
                        end
                        i <= i + 5'd1;
                    end else begin
                        // Done checking
                        if (is_palindrome) begin
                            // Already palindrome: output = input
                            for (int idx = 0; idx < 16; idx = idx + 1) begin
                                if (idx < input_len) begin
                                    output_str[idx] <= input_str[idx];
                                end else begin
                                    output_str[idx] <= 8'd0;
                                end
                            end
                            for (int idx = 16; idx < 32; idx = idx + 1) begin
                                output_str[idx] <= 8'd0;
                            end
                            output_len <= {1'b0, input_len};
                            state <= FINISH;
                        end else begin
                            // Find longest palindromic suffix
                            state <= FIND_SUFFIX;
                            len_k <= 5'd0;  // Default to 0 if none found
                            suffix_len <= input_len - 5'd1;  // Start from max suffix length
                            suffix_start <= 5'd0;
                            i <= 5'd0;
                        end
                    end
                end
                
                FIND_SUFFIX: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Check suffixes from longest to shortest
                    if (suffix_len > 5'd0) begin
                        // Check if suffix of length suffix_len is palindrome
                        if (i < (suffix_len >> 1)) begin
                            // Compare suffix_len-i-1 with i
                            compare_idx <= i;
                            compare_end <= suffix_len - 1 - i;
                            i <= i + 5'd1;
                            mismatch <= 1'b0;
                        end else begin
                            // Done checking this suffix length
                            if (!mismatch && (suffix_len > len_k)) begin
                                len_k <= suffix_len;
                            end
                            // Try next shorter suffix
                            suffix_len <= suffix_len - 5'd1;
                            i <= 5'd0;
                        end
                    end else begin
                        // No palindromic suffix found (len_k = 0)
                        state <= BUILD_OUTPUT;
                        prefix_len <= input_len - len_k;
                        build_idx <= 5'd0;
                        build_idx2 <= 5'd0;
                    end
                end
                
                BUILD_OUTPUT: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Build output: prefix + palindromic suffix + reverse(prefix)
                    if (build_idx < prefix_len) begin
                        // Copy prefix from input
                        temp_output[build_idx] <= input_str[build_idx];
                        build_idx <= build_idx + 5'd1;
                    end else if (build_idx < prefix_len + len_k) begin
                        // Copy palindromic suffix from input
                        temp_output[build_idx] <= input_str[build_idx];
                        build_idx <= build_idx + 5'd1;
                    end else if (build_idx < prefix_len + len_k + prefix_len) begin
                        // Copy reverse of prefix
                        temp_output[build_idx] <= input_str[prefix_len - 1 - build_idx2];
                        build_idx <= build_idx + 5'd1;
                        build_idx2 <= build_idx2 + 5'd1;
                    end else begin
                        // Done building
                        output_len <= {1'b0, prefix_len} + {1'b0, len_k} + {1'b0, prefix_len};
                        for (int idx = 0; idx < 32; idx = idx + 1) begin
                            if (idx < (prefix_len + len_k + prefix_len)) begin
                                output_str[idx] <= temp_output[idx];
                            end else begin
                                output_str[idx] <= 8'd0;
                            end
                        end
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational logic for FIND_SUFFIX comparison
    always @(*) begin
        if (state == FIND_SUFFIX && i > 5'd0) begin
            if (input_str[compare_idx] != input_str[input_len - suffix_len + compare_end]) begin
                mismatch = 1'b1;
            end else begin
                mismatch = 1'b0;
            end
        end else begin
            mismatch = 1'b0;
        end
    end

endmodule