module bracket_checker(
    input clk,
    input rst_n,
    input start,
    input [127:0] expr,
    input [3:0] length,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    // Stack and pointer
    reg [1:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] char_index;
    reg valid;
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Character type codes
    localparam [1:0] PAREN = 2'd0;
    localparam [1:0] BRACE = 2'd1;
    localparam [1:0] BRACKET = 2'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            stack_ptr <= 4'd0;
            char_index <= 4'd0;
            valid <= 1'b1;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        char_index <= 4'd0;
                        stack_ptr <= 4'd0;
                        valid <= 1'b1;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all characters
                    if (char_index == length || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Extract current character
                        reg [7:0] current_char = expr[(char_index * 8) +: 8];
                        
                        // Check for opening brackets
                        if (current_char == 8'h28) begin // '('
                            stack[stack_ptr] <= PAREN;
                            stack_ptr <= stack_ptr + 4'd1;
                        end else if (current_char == 8'h7B) begin // '{'
                            stack[stack_ptr] <= BRACE;
                            stack_ptr <= stack_ptr + 4'd1;
                        end else if (current_char == 8'h5B) begin // '['
                            stack[stack_ptr] <= BRACKET;
                            stack_ptr <= stack_ptr + 4'd1;
                        end
                        // Check for closing brackets
                        else if (current_char == 8'h29) begin // ')'
                            if (stack_ptr == 4'd0) begin
                                valid <= 1'b0;
                            end else begin
                                stack_ptr <= stack_ptr - 4'd1;
                                if (stack[stack_ptr] != PAREN) begin
                                    valid <= 1'b0;
                                end
                            end
                        end else if (current_char == 8'h7D) begin // '}'
                            if (stack_ptr == 4'd0) begin
                                valid <= 1'b0;
                            end else begin
                                stack_ptr <= stack_ptr - 4'd1;
                                if (stack[stack_ptr] != BRACE) begin
                                    valid <= 1'b0;
                                end
                            end
                        end else if (current_char == 8'h5D) begin // ']'
                            if (stack_ptr == 4'd0) begin
                                valid <= 1'b0;
                            end else begin
                                stack_ptr <= stack_ptr - 4'd1;
                                if (stack[stack_ptr] != BRACKET) begin
                                    valid <= 1'b0;
                                end
                            end
                        end
                        
                        char_index <= char_index + 4'd1;
                    end
                end

                FINISH: begin
                    // Result is valid only if stack is empty and valid flag is set
                    if (stack_ptr == 4'd0 && valid) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule