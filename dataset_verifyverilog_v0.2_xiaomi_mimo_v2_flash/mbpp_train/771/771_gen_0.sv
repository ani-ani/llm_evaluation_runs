module balanced_parentheses(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    output reg balanced,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PUSH = 3'b001;
    localparam POP  = 3'b010;
    localparam VALIDATE = 3'b011;
    localparam ERROR = 3'b100;
    localparam COMPLETE = 3'b101;

    // Current state register
    reg [2:0] state;
    
    // Index to track which character is being processed (0-7)
    reg [2:0] char_idx;
    
    // Stack pointer (3 bits, depth 0-7)
    reg [2:0] sp;
    
    // Stack memory: 8 slots. 0=None, 1='(', 2='{', 3='['
    reg [1:0] stack [0:7];
    
    // Input character buffer to ensure stability during processing
    reg [7:0] current_char;
    
    // Combinational logic for bracket matching
    wire is_opening;
    wire is_closing;
    wire [1:0] opening_type;
    wire match_ok;
    
    // Decode current character
    assign is_opening = (current_char == 8'h28) || (current_char == 8'h7B) || (current_char == 8'h5B);
    assign is_closing = (current_char == 8'h29) || (current_char == 8'h7D) || (current_char == 8'h5D);
    
    // Determine opening type
    assign opening_type = (current_char == 8'h28) ? 2'd1 :
                          (current_char == 8'h7B) ? 2'd2 :
                          (current_char == 8'h5B) ? 2'd3 : 2'd0;
    
    // Matching logic for POP state
    // Map closing brackets to their opening types: ')'->1, '}'->2, ']'->3
    wire [1:0] expected_opening;
    assign expected_opening = (current_char == 8'h29) ? 2'd1 :
                              (current_char == 8'h7D) ? 2'd2 :
                              (current_char == 8'h5D) ? 2'd3 : 2'd0;
    
    assign match_ok = (sp != 0) && (stack[sp - 1] == expected_opening);
    
    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 3'd0;
            sp <= 3'd0;
            balanced <= 1'b0;
            done <= 1'b0;
            current_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    balanced <= 1'b0;
                    char_idx <= 3'd0;
                    sp <= 3'd0;
                    if (start) begin
                        state <= PUSH;
                        // Load first character immediately for processing
                        current_char <= char_0;
                    end
                end
                
                PUSH: begin
                    // Check if current character is opening bracket
                    if (is_opening) begin
                        if (sp < 3'd8) begin
                            stack[sp] <= opening_type;
                            sp <= sp + 1;
                        end else begin
                            // Stack overflow - treat as error (optional, spec says max depth 8)
                            state <= ERROR;
                            done <= 1'b1;
                            balanced <= 1'b0;
                        end
                    end
                    
                    // Transition to POP state to check for closing brackets
                    state <= POP;
                end
                
                POP: begin
                    // Check if current character is closing bracket
                    if (is_closing) begin
                        if (match_ok) begin
                            sp <= sp - 1;
                        end else begin
                            // Mismatch or stack underflow
                            state <= ERROR;
                            done <= 1'b1;
                            balanced <= 1'b0;
                        end
                    end
                    
                    // Move to next character or validate
                    if (char_idx < 3'd7) begin
                        char_idx <= char_idx + 1;
                        state <= PUSH;
                        // Load next character based on index
                        case (char_idx + 1)
                            3'd1: current_char <= char_1;
                            3'd2: current_char <= char_2;
                            3'd3: current_char <= char_3;
                            3'd4: current_char <= char_4;
                            3'd5: current_char <= char_5;
                            3'd6: current_char <= char_6;
                            3'd7: current_char <= char_7;
                            default: current_char <= 8'd0;
                        endcase
                    end else begin
                        // All 8 characters processed
                        state <= VALIDATE;
                    end
                end
                
                VALIDATE: begin
                    if (sp == 3'd0) begin
                        state <= COMPLETE;
                        balanced <= 1'b1;
                    end else begin
                        state <= ERROR;
                        balanced <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                ERROR: begin
                    // Remain in error state until reset
                    state <= ERROR;
                    done <= 1'b1;
                    balanced <= 1'b0;
                end
                
                COMPLETE: begin
                    // Remain in complete state until reset
                    state <= COMPLETE;
                    done <= 1'b1;
                    balanced <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
