module vowel_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] CHECK_FIRST = 2'd1;
    localparam [1:0] CHECK_REST  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] current_byte;
    reg vowel_found;
    reg all_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            current_byte <= 8'd0;
            vowel_found <= 1'b0;
            all_valid <= 1'b1;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state <= CHECK_FIRST;
                        index <= 4'd0;
                        vowel_found <= 1'b0;
                        all_valid <= 1'b1;
                    end
                end

                CHECK_FIRST: begin
                    current_byte <= str[7:0];
                    if (len == 4'd0) begin
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        // Check if first byte is a vowel
                        if ((current_byte == 8'd65) ||   // 'A'
                            (current_byte == 8'd69) ||   // 'E'
                            (current_byte == 8'd73) ||   // 'I'
                            (current_byte == 8'd79) ||   // 'O'
                            (current_byte == 8'd85) ||   // 'U'
                            (current_byte == 8'd97) ||   // 'a'
                            (current_byte == 8'd101) ||  // 'e'
                            (current_byte == 8'd105) ||  // 'i'
                            (current_byte == 8'd109) ||  // 'o'
                            (current_byte == 8'd111) ||  // 'u'
                            (current_byte == 8'd0)) begin // null terminator
                            vowel_found <= 1'b1;
                        end else begin
                            vowel_found <= 1'b0;
                        end

                        if (len == 4'd1) begin
                            result <= vowel_found;
                            state <= DONE_STATE;
                        end else begin
                            index <= 4'd1;
                            state <= CHECK_REST;
                        end
                    end
                end

                CHECK_REST: begin
                    current_byte <= str[(index * 8) +: 8];
                    // Check if current byte is alphanumeric or underscore
                    if ((current_byte >= 8'd48 && current_byte <= 8'd57) ||  // 0-9
                        (current_byte >= 8'd65 && current_byte <= 8'd90) ||  // A-Z
                        (current_byte >= 8'd97 && current_byte <= 8'd122) || // a-z
                        (current_byte == 8'd95) ||                          // _
                        (current_byte == 8'd0)) begin                        // null terminator
                        all_valid <= all_valid & 1'b1;
                    end else begin
                        all_valid <= 1'b0;
                    end

                    if (index == len - 4'd1) begin
                        result <= vowel_found & all_valid;
                        state <= DONE_STATE;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule