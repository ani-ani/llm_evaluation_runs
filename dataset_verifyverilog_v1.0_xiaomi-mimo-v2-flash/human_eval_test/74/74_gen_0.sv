module total_match (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] len1,
    input wire [2:0] len2,
    input wire str1_valid,
    input wire str2_valid,
    input wire [7:0] char_data,
    input wire char_valid,
    output reg [1:0] result_select,
    output reg [2:0] result_len,
    output reg result_ready,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COUNT1   = 3'd1;
    localparam [2:0] COUNT2   = 3'd2;
    localparam [2:0] COMPARE  = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;
    localparam [2:0] DONE     = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] current_str_idx;
    reg [2:0] str_count_target;
    reg [15:0] total_chars;
    reg [15:0] total1, total2;
    reg in_list1;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COUNT1;
                else
                    next_state = IDLE;
            end
            
            COUNT1: begin
                // Check if all strings in list 1 are processed
                if (current_str_idx >= len1) begin
                    next_state = COUNT2;
                end else begin
                    // Stay in COUNT1 until char_valid goes low (end of string)
                    if (!char_valid && current_str_idx > 8'd0) begin
                        next_state = COUNT1; // Wait for next string
                    end else begin
                        next_state = COUNT1;
                    end
                end
            end
            
            COUNT2: begin
                // Check if all strings in list 2 are processed
                if (current_str_idx >= len2) begin
                    next_state = COMPARE;
                end else begin
                    // Stay in COUNT2 until char_valid goes low (end of string)
                    if (!char_valid && current_str_idx > 8'd0) begin
                        next_state = COUNT2; // Wait for next string
                    end else begin
                        next_state = COUNT2;
                    end
                end
            end
            
            COMPARE: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_select <= 2'd0;
            result_len <= 3'd0;
            result_ready <= 1'b0;
            done <= 1'b0;
            current_str_idx <= 3'd0;
            total_chars <= 16'd0;
            total1 <= 16'd0;
            total2 <= 16'd0;
            in_list1 <= 1'b1;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            // Default outputs
            result_ready <= 1'b0;
            done <= 1'b0;
            
            // Increment cycle counter (protect against stalls)
            if (state != IDLE && state != DONE) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                cycle_count <= 8'd0;
            end
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_str_idx <= 3'd0;
                        total_chars <= 16'd0;
                        total1 <= 16'd0;
                        total2 <= 16'd0;
                        in_list1 <= 1'b1;
                    end
                end
                
                COUNT1: begin
                    // Count characters for current string in list 1
                    if (char_valid && str1_valid) begin
                        total_chars <= total_chars + 16'd1;
                    end
                    
                    // Check for end of string (char_valid goes low after string)
                    if (!char_valid && current_str_idx < len1 && str1_valid) begin
                        // Move to next string
                        if (current_str_idx < 8'd7) begin
                            current_str_idx <= current_str_idx + 3'd1;
                        end
                    end else if (!char_valid && current_str_idx == len1 - 3'd1) begin
                        // Last string finished
                        total1 <= total_chars;
                        total_chars <= 16'd0;
                        current_str_idx <= 3'd0;
                    end
                end
                
                COUNT2: begin
                    in_list1 <= 1'b0;
                    
                    // Count characters for current string in list 2
                    if (char_valid && str2_valid) begin
                        total_chars <= total_chars + 16'd1;
                    end
                    
                    // Check for end of string
                    if (!char_valid && current_str_idx < len2 && str2_valid) begin
                        // Move to next string
                        if (current_str_idx < 8'd7) begin
                            current_str_idx <= current_str_idx + 3'd1;
                        end
                    end else if (!char_valid && current_str_idx == len2 - 3'd1) begin
                        // Last string finished
                        total2 <= total_chars;
                    end
                end
                
                COMPARE: begin
                    // Set selection based on comparison
                    if (total1 <= total2) begin
                        result_select <= 2'd0; // First list (including equal)
                        result_len <= len1;
                    end else begin
                        result_select <= 2'd1; // Second list
                        result_len <= len2;
                    end
                end
                
                OUTPUT: begin
                    result_ready <= 1'b1;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule