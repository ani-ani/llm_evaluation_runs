module is_nested(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    input [3:0] str_len,
    output reg result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] depth;
    reg [3:0] len_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            depth <= 4'd0;
            len_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        index <= 4'd0;
                        depth <= 4'd0;
                        result <= 1'b0;
                        len_reg <= str_len;
                    end
                end
                
                PROCESSING: begin
                    if (index < len_reg) begin
                        // Check current character
                        if (str[index] == 8'd91) begin // '[' ASCII 91
                            if (depth > 4'd0) begin
                                result <= 1'b1; // Nesting detected
                            end
                            depth <= depth + 4'd1;
                        end else if (str[index] == 8'd93) begin // ']' ASCII 93
                            depth <= depth - 4'd1;
                        end
                        index <= index + 4'd1;
                    end else begin
                        // Reached end of string
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule