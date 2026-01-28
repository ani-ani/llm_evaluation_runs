module digit_rearranger(
    input clk,
    input rst_n,
    input start,
    input [3:0] data_in,
    input data_valid,
    output reg [3:0] data_out,
    output reg out_valid,
    output reg done,
    output reg error
);

    localparam [3:0] MAX_DIGITS = 20;
    
    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COLLECT  = 2'd1;
    localparam [1:0] COMPUTE  = 2'd2;
    localparam [1:0] OUTPUT   = 2'd3;
    
    // Valid permutations of 1,6,8,9
    localparam [15:0] PERM_1869 = 16'd1869;
    localparam [15:0] PERM_1968 = 16'd1968;
    localparam [15:0] PERM_1689 = 16'd1689;
    localparam [15:0] PERM_6198 = 16'd6198;
    localparam [15:0] PERM_1698 = 16'd1698;
    localparam [15:0] PERM_1986 = 16'd1986;
    localparam [15:0] PERM_1896 = 16'd1896;
    localparam [15:0] PERM_8691 = 16'd8691;
    
    // State registers
    reg [1:0] state, next_state;
    reg [7:0] digit_count [0:9];
    reg [7:0] input_digits [0:19];
    reg [7:0] input_pos;
    reg [7:0] output_pos;
    reg [7:0] total_digits;
    reg [2:0] mod7_result;
    reg [15:0] chosen_perm;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Reset digit counts
            integer i;
            for (i = 0; i < 10; i = i + 1) begin
                digit_count[i] <= 8'd0;
            end
            
            // Reset input storage
            for (i = 0; i < 20; i = i + 1) begin
                input_digits[i] <= 8'd0;
            end
            
            input_pos <= 8'd0;
            output_pos <= 8'd0;
            total_digits <= 8'd0;
            mod7_result <= 3'd0;
            chosen_perm <= 16'd0;
            cycle_count <= 8'd0;
            data_out <= 4'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    
                    if (start) begin
                        next_state <= COLLECT;
                        input_pos <= 8'd0;
                        total_digits <= 8'd0;
                        mod7_result <= 3'd0;
                        
                        // Reset digit counts
                        integer i;
                        for (i = 0; i < 10; i = i + 1) begin
                            digit_count[i] <= 8'd0;
                        end
                    end
                end
                
                COLLECT: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    
                    if (data_valid) begin
                        // Store input digit
                        input_digits[input_pos] <= data_in;
                        
                        // Update digit count
                        digit_count[data_in] <= digit_count[data_in] + 8'd1;
                        
                        // Update modulo 7
                        mod7_result <= (mod7_result * 7'd10 + data_in) % 7'd7;
                        
                        input_pos <= input_pos + 8'd1;
                        total_digits <= total_digits + 8'd1;
                        
                        if (input_pos == MAX_DIGITS - 4'd1 || !data_valid) begin
                            next_state <= COMPUTE;
                            cycle_count <= 8'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count == 8'd1) begin
                        // Remove one occurrence each of 1,6,8,9
                        digit_count[1] <= digit_count[1] - 8'd1;
                        digit_count[6] <= digit_count[6] - 8'd1;
                        digit_count[8] <= digit_count[8] - 8'd1;
                        digit_count[9] <= digit_count[9] - 8'd1;
                        
                        // Find permutation that makes total divisible by 7
                        reg [15:0] test_perm;
                        reg [2:0] test_mod;
                        reg found;
                        
                        // Test each permutation
                        test_perm = PERM_1869;
                        test_mod = (mod7_result * 10000 + test_perm) % 7;
                        if (test_mod == 3'd0) begin
                            chosen_perm <= test_perm;
                            found = 1'b1;
                        end else begin
                            test_perm = PERM_1968;
                            test_mod = (mod7_result * 10000 + test_perm) % 7;
                            if (test_mod == 3'd0) begin
                                chosen_perm <= test_perm;
                                found = 1'b1;
                            end else begin
                                test_perm = PERM_1689;
                                test_mod = (mod7_result * 10000 + test_perm) % 7;
                                if (test_mod == 3'd0) begin
                                    chosen_perm <= test_perm;
                                    found = 1'b1;
                                end else begin
                                    test_perm = PERM_6198;
                                    test_mod = (mod7_result * 10000 + test_perm) % 7;
                                    if (test_mod == 3'd0) begin
                                        chosen_perm <= test_perm;
                                        found = 1'b1;
                                    end else begin
                                        test_perm = PERM_1698;
                                        test_mod = (mod7_result * 10000 + test_perm) % 7;
                                        if (test_mod == 3'd0) begin
                                            chosen_perm <= test_perm;
                                            found = 1'b1;
                                        end else begin
                                            test_perm = PERM_1986;
                                            test_mod = (mod7_result * 10000 + test_perm) % 7;
                                            if (test_mod == 3'd0) begin
                                                chosen_perm <= test_perm;
                                                found = 1'b1;
                                            end else begin
                                                test_perm = PERM_1896;
                                                test_mod = (mod7_result * 10000 + test_perm) % 7;
                                                if (test_mod == 3'd0) begin
                                                    chosen_perm <= test_perm;
                                                    found = 1'b1;
                                                end else begin
                                                    test_perm = PERM_8691;
                                                    test_mod = (mod7_result * 10000 + test_perm) % 7;
                                                    if (test_mod == 3'd0) begin
                                                        chosen_perm <= test_perm;
                                                        found = 1'b1;
                                                    end else begin
                                                        found = 1'b0;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        if (found) begin
                            next_state <= OUTPUT;
                            output_pos <= 8'd0;
                        end else begin
                            error <= 1'b1;
                            next_state <= IDLE;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        error <= 1'b1;
                        next_state <= IDLE;
                    end
                end
                
                OUTPUT: begin
                    reg [7:0] current_pos;
                    current_pos = output_pos;
                    
                    if (current_pos < total_digits) begin
                        // Output non-zero digits (excluding one each of 1,6,8,9)
                        reg [3:0] current_digit;
                        current_digit = input_digits[current_pos];
                        
                        // Skip if this is one of the removed digits (1,6,8,9)
                        reg [7:0] count_1, count_6, count_8, count_9;
                        count_1 = digit_count[1];
                        count_6 = digit_count[6];
                        count_8 = digit_count[8];
                        count_9 = digit_count[9];
                        
                        if ((current_digit == 4'd1 && count_1 > 8'd0) ||
                            (current_digit == 4'd6 && count_6 > 8'd0) ||
                            (current_digit == 4'd8 && count_8 > 8'd0) ||
                            (current_digit == 4'd9 && count_9 > 8'd0) ||
                            (current_digit != 4'd1 && current_digit != 4'd6 &&
                             current_digit != 4'd8 && current_digit != 4'd9)) begin
                            
                            data_out <= current_digit;
                            out_valid <= 1'b1;
                            output_pos <= output_pos + 8'd1;
                        end else begin
                            output_pos <= output_pos + 8'd1;
                        end
                    end else if (current_pos < total_digits + 4'd4) begin
                        // Output the 4-digit permutation
                        reg [7:0] perm_pos;
                        perm_pos = current_pos - total_digits;
                        
                        case (perm_pos)
                            4'd0: data_out <= chosen_perm[15:12];
                            4'd1: data_out <= chosen_perm[11:8];
                            4'd2: data_out <= chosen_perm[7:4];
                            4'd3: data_out <= chosen_perm[3:0];
                        endcase
                        
                        out_valid <= 1'b1;
                        output_pos <= output_pos + 8'd1;
                    end else if (current_pos < total_digits + 4'd4 + digit_count[0]) begin
                        // Output remaining zeros
                        data_out <= 4'd0;
                        out_valid <= 1'b1;
                        output_pos <= output_pos + 8'd1;
                    end else begin
                        // Done
                        done <= 1'b1;
                        out_valid <= 1'b0;
                        next_state <= IDLE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Handle special case where only 1,6,8,9 are present
    always @(posedge clk) begin
        if (state == COMPUTE && cycle_count == 8'd1) begin
            reg all_special;
            integer i;
            all_special = 1'b1;
            
            for (i = 0; i < 10; i = i + 1) begin
                if (i != 1 && i != 6 && i != 8 && i != 9 && digit_count[i] > 8'd0) begin
                    all_special = 1'b0;
                end
            end
            
            if (all_special) begin
                // Output permutation with trailing zeros
                chosen_perm <= PERM_1869; // Default choice
                next_state <= OUTPUT;
                output_pos <= 8'd0;
            end
        end
    end

endmodule