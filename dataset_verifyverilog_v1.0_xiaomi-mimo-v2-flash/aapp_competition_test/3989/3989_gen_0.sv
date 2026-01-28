module digit_7_divisible(
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

    // Parameters
    localparam [7:0] MAX_DIGITS = 8'd20;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COLLECT    = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] DONE       = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Digit counters (10 digits, 4-bit each)
    reg [3:0] counts[0:9];
    reg [3:0] i;
    
    // Temporary storage for modulo computation
    reg [2:0] current_mod;
    reg [3:0] digit_idx;
    reg [3:0] digit_count_remain;
    reg [3:0] output_digit_count;
    reg [3:0] output_stage; // 0: non-zero digits, 1: permutation, 2: zeros
    reg [3:0] perm_idx;
    reg [2:0] perm_index;
    
    // Valid permutations for 1,6,8,9 (8 permutations)
    wire [13:0] perms [0:7]; // Each 14-bit (4 digits x 3.5 bits, but we use decimal)
    assign perms[0] = 14'd1869;
    assign perms[1] = 14'd1968;
    assign perms[2] = 14'd1689;
    assign perms[3] = 14'd6198;
    assign perms[4] = 14'd1698;
    assign perms[5] = 14'd1986;
    assign perms[6] = 14'd1896;
    assign perms[7] = 14'd8691;
    
    reg [2:0] perm_index_reg;
    reg [13:0] selected_perm;
    
    // Control signals
    reg [7:0] cycle_count;
    reg [3:0] digit_counter;
    reg temp_done;
    reg error_reg;
    
    // For output generation
    reg [3:0] output_digits[0:23]; // Max 20 original + 4 new = 24
    reg [4:0] output_ptr;
    reg [4:0] output_total;
    reg output_started;
    
    // FSM Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_mod <= 3'd0;
            digit_idx <= 4'd0;
            digit_count_remain <= 4'd0;
            output_digit_count <= 4'd0;
            output_stage <= 3'd0;
            perm_idx <= 4'd0;
            perm_index <= 3'd0;
            perm_index_reg <= 3'd0;
            selected_perm <= 14'd0;
            cycle_count <= 8'd0;
            digit_counter <= 4'd0;
            temp_done <= 1'b0;
            error_reg <= 1'b0;
            output_ptr <= 5'd0;
            output_total <= 5'd0;
            output_started <= 1'b0;
            data_out <= 4'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            
            // Initialize counters
            for (i = 0; i < 10; i = i + 1) begin
                counts[i] <= 4'd0;
            end
            // Initialize output digits
            for (i = 0; i < 24; i = i + 1) begin
                output_digits[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    temp_done <= 1'b0;
                    error_reg <= 1'b0;
                    cycle_count <= 8'd0;
                    current_mod <= 3'd0;
                    digit_counter <= 4'd0;
                    output_ptr <= 5'd0;
                    output_total <= 5'd0;
                    output_started <= 1'b0;
                    
                    // Initialize all counts to 0
                    for (i = 0; i < 10; i = i + 1) begin
                        counts[i] <= 4'd0;
                    end
                    // Initialize output digits
                    for (i = 0; i < 24; i = i + 1) begin
                        output_digits[i] <= 4'd0;
                    end
                    
                    if (start) begin
                        // Reset state will happen on next clock
                    end
                end
                
                COLLECT: begin
                    if (data_valid && (digit_counter < MAX_DIGITS)) begin
                        // Increment count for digit
                        counts[data_in] <= counts[data_in] + 4'd1;
                        digit_counter <= digit_counter + 4'd1;
                    end
                end
                
                COMPUTE: begin
                    // Step 1: Remove one occurrence each of 1,6,8,9
                    if (cycle_count == 8'd0) begin
                        counts[1] <= (counts[1] > 0) ? counts[1] - 4'd1 : 4'd0;
                        counts[6] <= (counts[6] > 0) ? counts[6] - 4'd1 : 4'd0;
                        counts[8] <= (counts[8] > 0) ? counts[8] - 4'd1 : 4'd0;
                        counts[9] <= (counts[9] > 0) ? counts[9] - 4'd1 : 4'd0;
                        current_mod <= 3'd0;
                        digit_idx <= 4'd0;
                    end
                    // Step 2: Compute modulo 7 of remaining digits (in order 0-9)
                    else if (cycle_count <= 8'd10) begin
                        // Process digit (cycle_count-1) which is 0-9
                        if (digit_idx < 10) begin
                            digit_count_remain <= counts[digit_idx];
                            if (counts[digit_idx] > 0) begin
                                // Compute (current_mod * 10 + digit_idx) mod 7
                                current_mod <= (current_mod * 3 + digit_idx) % 7;
                            end
                            digit_idx <= digit_idx + 4'd1;
                        end
                    end
                    // Step 3: Find valid permutation
                    else if (cycle_count <= 8'd20) begin
                        if (cycle_count == 8'd11) begin
                            perm_idx <= 4'd0;
                            perm_index <= 3'd0;
                            error_reg <= 1'b1; // Assume error until found
                        end else if (perm_idx < 8) begin
                            // Check if this permutation works
                            if (((current_mod * 32 + perms[perm_idx] % 10000) % 7 == 0) && error_reg) begin
                                selected_perm <= perms[perm_idx];
                                perm_index_reg <= perm_idx;
                                error_reg <= 1'b0;
                            end
                            perm_idx <= perm_idx + 4'd1;
                        end
                    end
                    // Step 4: Prepare output array
                    else if (cycle_count <= 8'd35) begin
                        if (cycle_count == 8'd21) begin
                            output_ptr <= 5'd0;
                            digit_idx <= 4'd0;
                        end
                        
                        // Add non-zero digits (except the removed ones)
                        if (cycle_count >= 8'd22 && cycle_count <= 8'd31) begin
                            if (digit_idx < 10) begin
                                if (digit_idx != 1 && digit_idx != 6 && digit_idx != 8 && digit_idx != 9) begin
                                    if (counts[digit_idx] > 0) begin
                                        for (int j = 0; j < 10; j = j + 1) begin
                                            if (j < counts[digit_idx]) begin
                                                output_digits[output_ptr + j] <= digit_idx;
                                            end
                                        end
                                        output_ptr <= output_ptr + counts[digit_idx];
                                    end
                                end
                                digit_idx <= digit_idx + 4'd1;
                            end
                        end
                        
                        // Add the permutation
                        if (cycle_count == 8'd32) begin
                            output_digits[output_ptr] <= selected_perm[13:10];
                            output_digits[output_ptr + 4'd1] <= selected_perm[9:6];
                            output_digits[output_ptr + 4'd2] <= selected_perm[5:2];
                            output_digits[output_ptr + 4'd3] <= selected_perm[1:0];
                            output_ptr <= output_ptr + 5'd4;
                            output_total <= output_ptr + 5'd4;
                        end
                        
                        // Add zeros
                        if (cycle_count >= 8'd33 && cycle_count <= 8'd35) begin
                            if (counts[0] > 0) begin
                                for (int j = 0; j < 10; j = j + 1) begin
                                    if (j < counts[0]) begin
                                        output_digits[output_ptr + j] <= 4'd0;
                                    end
                                end
                                output_ptr <= output_ptr + counts[0];
                                output_total <= output_ptr + counts[0];
                            end
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                end
                
                OUTPUT: begin
                    // Generate output stream
                    if (output_ptr < output_total) begin
                        data_out <= output_digits[output_ptr];
                        out_valid <= 1'b1;
                        output_ptr <= output_ptr + 5'd1;
                    end else begin
                        out_valid <= 1'b0;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    error <= error_reg;
                    out_valid <= 1'b0;
                    data_out <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COLLECT;
            end
            
            COLLECT: begin
                if (!data_valid && (digit_counter >= MAX_DIGITS || digit_counter == 4'd0)) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (cycle_count > MAX_CYCLES) begin
                    next_state = DONE;
                end else if (cycle_count > 8'd35) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                if (output_ptr >= output_total) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule