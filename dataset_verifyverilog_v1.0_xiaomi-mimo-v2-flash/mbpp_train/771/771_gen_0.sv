module bracket_balancer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] expr,
    input wire [3:0] length,
    output reg result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Bracket type codes
    localparam [1:0] TYPE_PAREN = 2'd0;   // '(' 
    localparam [1:0] TYPE_CURLY = 2'd1;   // '{'
    localparam [1:0] TYPE_SQUARE = 2'd2;  // '['

    // ASCII codes
    localparam [7:0] ASCII_OPEN_PAREN = 8'h28;
    localparam [7:0] ASCII_CLOSE_PAREN = 8'h29;
    localparam [7:0] ASCII_OPEN_CURLY = 8'h7B;
    localparam [7:0] ASCII_CLOSE_CURLY = 8'h7D;
    localparam [7:0] ASCII_OPEN_SQUARE = 8'h5B;
    localparam [7:0] ASCII_CLOSE_SQUARE = 8'h5D;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] stack_ptr;
    reg [3:0] next_stack_ptr;
    reg valid;
    reg next_valid;
    reg [3:0] index;
    reg [3:0] next_index;
    reg [1:0] stack [0:15];  // Stack array for 16 elements, 2 bits each
    reg [1:0] stack_top;     // Current top of stack (for comparison)
    reg [1:0] next_stack_top; // Next value to push
    reg push_en;
    reg pop_en;

    // Combinational logic for character extraction and comparison
    reg [7:0] current_char;
    reg is_opening;
    reg is_closing;
    reg [1:0] char_type;
    reg match_error;

    integer i;

    // Extract current character from expr based on index
    always @(*) begin
        case (index)
            4'd0: current_char = expr[7:0];
            4'd1: current_char = expr[15:8];
            4'd2: current_char = expr[23:16];
            4'd3: current_char = expr[31:24];
            4'd4: current_char = expr[39:32];
            4'd5: current_char = expr[47:40];
            4'd6: current_char = expr[55:48];
            4'd7: current_char = expr[63:56];
            4'd8: current_char = expr[71:64];
            4'd9: current_char = expr[79:72];
            4'd10: current_char = expr[87:80];
            4'd11: current_char = expr[95:88];
            4'd12: current_char = expr[103:96];
            4'd13: current_char = expr[111:104];
            4'd14: current_char = expr[119:112];
            4'd15: current_char = expr[127:120];
            default: current_char = 8'h00;
        endcase
    end

    // Determine character type and whether it's opening or closing
    always @(*) begin
        is_opening = 1'b0;
        is_closing = 1'b0;
        char_type = 2'b00;
        
        case (current_char)
            ASCII_OPEN_PAREN: begin
                is_opening = 1'b1;
                char_type = TYPE_PAREN;
            end
            ASCII_CLOSE_PAREN: begin
                is_closing = 1'b1;
                char_type = TYPE_PAREN;
            end
            ASCII_OPEN_CURLY: begin
                is_opening = 1'b1;
                char_type = TYPE_CURLY;
            end
            ASCII_CLOSE_CURLY: begin
                is_closing = 1'b1;
                char_type = TYPE_CURLY;
            end
            ASCII_OPEN_SQUARE: begin
                is_opening = 1'b1;
                char_type = TYPE_SQUARE;
            end
            ASCII_CLOSE_SQUARE: begin
                is_closing = 1'b1;
                char_type = TYPE_SQUARE;
            end
            default: begin
                // Non-bracket characters are ignored
                is_opening = 1'b0;
                is_closing = 1'b0;
            end
        endcase
    end

    // Stack management
    always @(*) begin
        // Default assignments
        next_stack_ptr = stack_ptr;
        next_valid = valid;
        next_index = index;
        push_en = 1'b0;
        pop_en = 1'b0;
        match_error = 1'b0;
        
        // Get stack top value for comparison
        stack_top = stack[stack_ptr - 4'd1];
        
        case (state)
            IDLE: begin
                next_stack_ptr = 4'd0;
                next_valid = 1'b1;
                next_index = 4'd0;
                if (start && (length != 4'd0)) begin
                    next_state = PROCESSING;
                end else if (start && (length == 4'd0)) begin
                    // Empty expression is balanced
                    next_state = FINISH;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESSING: begin
                // Process current character
                if (index < length) begin
                    if (is_opening) begin
                        // Push onto stack
                        if (stack_ptr < 4'd15) begin
                            next_stack_ptr = stack_ptr + 4'd1;
                            push_en = 1'b1;
                        end else begin
                            // Stack overflow - not balanced
                            next_valid = 1'b0;
                            next_state = FINISH;
                        end
                    end else if (is_closing) begin
                        // Check if stack is empty
                        if (stack_ptr == 4'd0) begin
                            // No matching opening bracket
                            next_valid = 1'b0;
                            next_state = FINISH;
                        end else begin
                            // Check for match
                            if (stack_top != char_type) begin
                                next_valid = 1'b0;
                                next_state = FINISH;
                            end else begin
                                // Match found - pop
                                next_stack_ptr = stack_ptr - 4'd1;
                                pop_en = 1'b1;
                            end
                        end
                    end
                    // Move to next character
                    next_index = index + 4'd1;
                end else begin
                    // End of expression
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                // Check final condition: valid AND stack empty
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_stack_ptr = 4'd0;
                next_valid = 1'b1;
                next_index = 4'd0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            stack_ptr <= 4'd0;
            valid <= 1'b1;
            index <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            // Initialize stack
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 2'b00;
            end
        end else begin
            state <= next_state;
            stack_ptr <= next_stack_ptr;
            valid <= next_valid;
            index <= next_index;
            
            // Handle stack operations
            if (push_en && (state == PROCESSING)) begin
                stack[stack_ptr] <= char_type;
            end
            
            // Output signals
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && (length == 4'd0)) begin
                        result <= 1'b1; // Empty expression is balanced
                        done <= 1'b1;
                    end
                end
                
                PROCESSING: begin
                    done <= 1'b0;
                end
                
                FINISH: begin
                    // Set result based on validity and empty stack
                    if (valid && (stack_ptr == 4'd0)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule