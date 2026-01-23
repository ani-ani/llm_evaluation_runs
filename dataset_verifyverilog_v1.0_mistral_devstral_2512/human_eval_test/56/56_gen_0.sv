module bracket_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE      = 2'd2;

    // Stack implementation (8 levels, 1-bit wide)
    reg [7:0] stack;
    reg [2:0] char_count;
    reg [1:0] state;

    // ASCII values
    localparam [7:0] OPEN_BRACKET  = 8'h3C;
    localparam [7:0] CLOSE_BRACKET = 8'h3E;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            char_count <= 3'd0;
            stack <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        char_count <= 3'd0;
                        stack <= 8'd0;
                    end
                end

                PROCESSING: begin
                    if (valid_in && char_count < 3'd8) begin
                        if (char_in == OPEN_BRACKET) begin
                            // Push to stack
                            stack <= {stack[6:0], 1'b1};
                        end else if (char_in == CLOSE_BRACKET) begin
                            // Check stack
                            if (stack[7] == 1'b1) begin
                                // Pop from stack
                                stack <= {stack[6:0], 1'b0};
                            end else begin
                                // Stack underflow
                                result <= 1'b0;
                                state <= DONE;
                            end
                        end
                        char_count <= char_count + 3'd1;
                    end else begin
                        // End of input stream
                        if (stack == 8'd0) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule