module parse_nested_parens (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COMPLETE   = 2'd2;

    // Character constants
    localparam [7:0] CHAR_SPACE = 8'h20;
    localparam [7:0] CHAR_LPAREN = 8'h28;
    localparam [7:0] CHAR_RPAREN = 8'h29;

    // Registers
    reg [1:0] state;
    reg [3:0] index;              // Current character index (0-15)
    reg [3:0] current_depth;      // Current nesting depth in group
    reg [3:0] max_depth;          // Maximum depth found
    reg in_group;                 // Flag: currently inside a group

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 4'd0;
            current_depth <= 4'd0;
            max_depth <= 4'd0;
            in_group <= 1'b0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    current_depth <= 4'd0;
                    max_depth <= 4'd0;
                    in_group <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Default: done stays low until complete
                    done <= 1'b0;
                    
                    // Process current character
                    if (char_array[index] == CHAR_LPAREN) begin
                        // Opening parenthesis
                        if (!in_group) begin
                            in_group <= 1'b1;
                            current_depth <= 4'd1;
                        end else begin
                            current_depth <= current_depth + 4'd1;
                        end
                        // Update max_depth
                        if ((in_group ? current_depth + 4'd1 : 4'd1) > max_depth) begin
                            if (in_group) begin
                                max_depth <= current_depth + 4'd1;
                            end else begin
                                max_depth <= 4'd1;
                            end
                        end
                    end else if (char_array[index] == CHAR_RPAREN) begin
                        // Closing parenthesis
                        if (current_depth > 4'd0) begin
                            current_depth <= current_depth - 4'd1;
                        end
                        if (current_depth - 4'd1 == 4'd0) begin
                            in_group <= 1'b0;
                        end
                    end else if (char_array[index] == CHAR_SPACE) begin
                        // Space resets group
                        in_group <= 1'b0;
                        current_depth <= 4'd0;
                    end
                    // Ignore all other characters

                    // Check if last character
                    if (index == 4'd15) begin
                        state <= COMPLETE;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                COMPLETE: begin
                    // Output result and done signal
                    result <= max_depth;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule