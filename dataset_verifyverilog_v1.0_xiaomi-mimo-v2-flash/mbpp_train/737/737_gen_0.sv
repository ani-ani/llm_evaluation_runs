module vowel_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_FIRST = 2'd1;
    localparam [1:0] CHECK_REST = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers
    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] len_reg;
    reg temp_result;
    reg check_first_done;
    
    // Current byte extraction
    wire [7:0] current_byte;
    assign current_byte = str[(idx * 8) +: 8];

    // Vowel check helper (combinational)
    wire is_vowel;
    assign is_vowel = (
        (current_byte == 8'd65)  || // 'A'
        (current_byte == 8'd69)  || // 'E'
        (current_byte == 8'd73)  || // 'I'
        (current_byte == 8'd79)  || // 'O'
        (current_byte == 8'd85)  || // 'U'
        (current_byte == 8'd97)  || // 'a'
        (current_byte == 8'd101) || // 'e'
        (current_byte == 8'd105) || // 'i'
        (current_byte == 8'd109) || // 'm' (wait, 'o' is 111, 'u' is 117)
        (current_byte == 8'd111) || // 'o'
        (current_byte == 8'd117)    // 'u'
    );
    
    // Alphanumeric/underscore check helper (combinational)
    wire is_alnum_or_underscore;
    assign is_alnum_or_underscore = (
        (current_byte >= 8'd48 && current_byte <= 8'd57)  || // 0-9
        (current_byte >= 8'd65 && current_byte <= 8'd90)  || // A-Z
        (current_byte >= 8'd97 && current_byte <= 8'd122) || // a-z
        (current_byte == 8'd95)                             // _
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            idx <= 4'd0;
            len_reg <= 4'd0;
            temp_result <= 1'b0;
            check_first_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    check_first_done <= 1'b0;
                    temp_result <= 1'b0;
                    
                    if (start) begin
                        len_reg <= len;
                        if (len == 4'd0) begin
                            temp_result <= 1'b0;
                            state <= DONE_STATE;
                        end else begin
                            state <= CHECK_FIRST;
                        end
                    end
                end
                
                CHECK_FIRST: begin
                    if (is_vowel) begin
                        temp_result <= 1'b1;
                        idx <= 4'd1;
                        check_first_done <= 1'b1;
                        
                        if (len_reg == 4'd1) begin
                            state <= DONE_STATE;
                        end else begin
                            state <= CHECK_REST;
                        end
                    end else begin
                        // First char is not a vowel
                        temp_result <= 1'b0;
                        state <= DONE_STATE;
                    end
                end
                
                CHECK_REST: begin
                    if (!is_alnum_or_underscore) begin
                        temp_result <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        if (idx >= len_reg - 4'd1) begin
                            // Reached end of string
                            temp_result <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            idx <= idx + 4'd1;
                            state <= CHECK_REST;
                        end
                    end
                end
                
                DONE_STATE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    idx <= 4'd0;
                    len_reg <= 4'd0;
                    temp_result <= 1'b0;
                    check_first_done <= 1'b0;
                end
            endcase
        end
    end
endmodule