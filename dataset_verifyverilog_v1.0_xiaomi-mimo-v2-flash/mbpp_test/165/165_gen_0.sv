module char_position_counter(
    input clk,
    input rst_n,
    input start,
    input [127:0] string_input,
    input [3:0] string_len,
    output reg [3:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [3:0] i;
    reg [3:0] count;
    reg [3:0] len_reg;
    reg [7:0] current_char;
    reg [7:0] upper_char;
    
    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            i <= 4'd0;
            count <= 4'd0;
            len_reg <= 4'd0;
            current_char <= 8'd0;
            upper_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    count <= 4'd0;
                    if (start) begin
                        len_reg <= string_len;
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    // Extract current character
                    current_char <= string_input[8*i +: 8];
                    
                    // Convert to uppercase (clear bit 5 for lowercase)
                    // If lowercase (a-z), char | 32 makes it uppercase
                    // If uppercase (A-Z), char | 32 keeps it unchanged
                    upper_char <= current_char | 8'd32;
                    
                    // Check if character matches position in alphabet
                    if (upper_char == (8'h41 + i)) begin
                        count <= count + 4'd1;
                    end
                    
                    // Check if we've processed all characters
                    if (i >= len_reg - 4'd1) begin
                        state <= DONE_STATE;
                    end else begin
                        i <= i + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 4'd0;
                    done <= 1'b0;
                    i <= 4'd0;
                    count <= 4'd0;
                    len_reg <= 4'd0;
                    current_char <= 8'd0;
                    upper_char <= 8'd0;
                end
            endcase
        end
    end
endmodule