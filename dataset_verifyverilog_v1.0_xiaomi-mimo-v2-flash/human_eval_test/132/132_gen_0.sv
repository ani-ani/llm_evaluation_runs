module nested_bracket_detector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_data,
    input wire char_valid,
    input wire char_done,
    output reg [1:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_CHAR = 3'd1;
    localparam [2:0] PROCESS_CHAR = 3'd2;
    localparam [2:0] CHECK_COMPLETE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    localparam [2:0] ERROR = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] stack_ptr;          // 4-bit for 0-15 (max 8 depth + overflow)
    reg [3:0] nesting_counter;    // 4-bit for 0-15 (max depth tracking)
    reg [3:0] max_depth;          // 4-bit for 0-15
    reg [7:0] char_reg;           // Store current character
    reg [4:0] cycle_count;        // 5-bit for 0-31 (max 16 chars * 2 cycles)
    reg stack [7:0];              // Stack array: 0 for '[', 1 for ']'
    reg is_valid;                 // Validity flag
    reg is_nested;                // Nesting flag
    reg start_prev;               // Detect start pulse
    reg char_done_prev;           // Detect char_done pulse
    reg char_valid_prev;          // Detect char_valid pulse
    
    // Stack signals (for synthesis)
    reg stack_0, stack_1, stack_2, stack_3, stack_4, stack_5, stack_6, stack_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            ready <= 1'b1;
            stack_ptr <= 4'd0;
            nesting_counter <= 4'd0;
            max_depth <= 4'd0;
            char_reg <= 8'd0;
            cycle_count <= 5'd0;
            is_valid <= 1'b1;
            is_nested <= 1'b0;
            start_prev <= 1'b0;
            char_done_prev <= 1'b0;
            char_valid_prev <= 1'b0;
            // Initialize stack registers
            stack_0 <= 1'b0;
            stack_1 <= 1'b0;
            stack_2 <= 1'b0;
            stack_3 <= 1'b0;
            stack_4 <= 1'b0;
            stack_5 <= 1'b0;
            stack_6 <= 1'b0;
            stack_7 <= 1'b0;
        end else begin
            // Edge detection
            start_prev <= start;
            char_done_prev <= char_done;
            char_valid_prev <= char_valid;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    result <= 2'd0;
                    cycle_count <= 5'd0;
                    stack_ptr <= 4'd0;
                    nesting_counter <= 4'd0;
                    max_depth <= 4'd0;
                    is_valid <= 1'b1;
                    is_nested <= 1'b0;
                    // Reset stack
                    stack_0 <= 1'b0;
                    stack_1 <= 1'b0;
                    stack_2 <= 1'b0;
                    stack_3 <= 1'b0;
                    stack_4 <= 1'b0;
                    stack_5 <= 1'b0;
                    stack_6 <= 1'b0;
                    stack_7 <= 1'b0;
                    
                    if (start && !start_prev) begin
                        state <= LOAD_CHAR;
                        ready <= 1'b0;
                    end
                end
                
                LOAD_CHAR: begin
                    if (char_valid && !char_valid_prev) begin
                        char_reg <= char_data;
                        state <= PROCESS_CHAR;
                        cycle_count <= cycle_count + 5'd1;
                    end
                    
                    // Timeout check (max 16 chars * 2 cycles = 32)
                    if (cycle_count >= 5'd32) begin
                        state <= FINISH;
                    end
                end
                
                PROCESS_CHAR: begin
                    // Only process if valid
                    if (is_valid) begin
                        if (char_reg == 8'h5B) begin // '[' ASCII
                            if (stack_ptr < 4'd8) begin
                                // Push to stack
                                case (stack_ptr)
                                    4'd0: stack_0 <= 1'b0; // '[' = 0
                                    4'd1: stack_1 <= 1'b0;
                                    4'd2: stack_2 <= 1'b0;
                                    4'd3: stack_3 <= 1'b0;
                                    4'd4: stack_4 <= 1'b0;
                                    4'd5: stack_5 <= 1'b0;
                                    4'd6: stack_6 <= 1'b0;
                                    4'd7: stack_7 <= 1'b0;
                                endcase
                                stack_ptr <= stack_ptr + 4'd1;
                                nesting_counter <= nesting_counter + 4'd1;
                                if (nesting_counter + 4'd1 > max_depth) begin
                                    max_depth <= nesting_counter + 4'd1;
                                end
                            end else begin
                                is_valid <= 1'b0; // Stack overflow
                            end
                        end else if (char_reg == 8'h5D) begin // ']' ASCII
                            if (stack_ptr > 4'd0) begin
                                // Pop from stack
                                stack_ptr <= stack_ptr - 4'd1;
                                // Check if this creates nesting
                                // We popped, so nesting is valid
                                // Mark as nested if we had depth > 1
                                if (nesting_counter > 4'd1) begin
                                    is_nested <= 1'b1;
                                end
                                nesting_counter <= nesting_counter - 4'd1;
                                
                                // Check mismatch
                                case (stack_ptr - 4'd1)
                                    4'd0: if (stack_0 != 1'b0) is_valid <= 1'b0;
                                    4'd1: if (stack_1 != 1'b0) is_valid <= 1'b0;
                                    4'd2: if (stack_2 != 1'b0) is_valid <= 1'b0;
                                    4'd3: if (stack_3 != 1'b0) is_valid <= 1'b0;
                                    4'd4: if (stack_4 != 1'b0) is_valid <= 1'b0;
                                    4'd5: if (stack_5 != 1'b0) is_valid <= 1'b0;
                                    4'd6: if (stack_6 != 1'b0) is_valid <= 1'b0;
                                    4'd7: if (stack_7 != 1'b0) is_valid <= 1'b0;
                                endcase
                            end else begin
                                is_valid <= 1'b0; // Empty stack pop
                            end
                        end else begin
                            // Invalid character - treat as error
                            is_valid <= 1'b0;
                        end
                    end
                    state <= CHECK_COMPLETE;
                end
                
                CHECK_COMPLETE: begin
                    if (char_done && !char_done_prev) begin
                        // End of string
                        if (stack_ptr == 4'd0 && is_valid) begin
                            if (max_depth == 4'd1) begin
                                result <= 2'd1; // Valid, no nesting
                            end else if (max_depth > 4'd1) begin
                                result <= 2'd10; // Valid with nesting
                            end else begin
                                result <= 2'd0; // Empty
                            end
                        end else begin
                            result <= 2'd0; // Unbalanced or invalid
                        end
                        state <= FINISH;
                    end else begin
                        // Wait for more characters
                        if (char_valid) begin
                            state <= LOAD_CHAR;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                    ready <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 2'd0;
                    done <= 1'b0;
                    ready <= 1'b1;
                end
            endcase
        end
    end
endmodule