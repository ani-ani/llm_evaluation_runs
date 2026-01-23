module string_transform(
    input clk,
    input rst_n,
    input start,
    input [127:0] data_in,
    output reg [127:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LETTERS = 3'd1;
    localparam [2:0] TRANSFORM = 3'd2;
    localparam [2:0] REVERSE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg has_letter;
    reg [7:0] temp_byte;
    reg [127:0] temp_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            has_letter <= 1'b0;
            temp_byte <= 8'd0;
            temp_result <= 128'd0;
            result <= 128'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= CHECK_LETTERS;
                        index <= 4'd0;
                        has_letter <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_LETTERS: begin
                    if (index < 4'd16) begin
                        temp_byte = data_in[8*index +: 8];
                        if ((temp_byte >= 8'h41 && temp_byte <= 8'h5A) || (temp_byte >= 8'h61 && temp_byte <= 8'h7A)) begin
                            has_letter <= 1'b1;
                        end
                        index <= index + 4'd1;
                        next_state <= CHECK_LETTERS;
                    end else begin
                        if (has_letter) begin
                            next_state <= TRANSFORM;
                            index <= 4'd0;
                        end else begin
                            next_state <= REVERSE;
                            index <= 4'd0;
                        end
                    end
                end

                TRANSFORM: begin
                    if (index < 4'd16) begin
                        temp_byte = data_in[8*index +: 8];
                        if ((temp_byte >= 8'h41 && temp_byte <= 8'h5A) || (temp_byte >= 8'h61 && temp_byte <= 8'h7A)) begin
                            temp_byte = temp_byte ^ 8'h20;
                        end
                        temp_result[8*index +: 8] = temp_byte;
                        index <= index + 4'd1;
                        next_state <= TRANSFORM;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                REVERSE: begin
                    if (index < 4'd16) begin
                        temp_result[8*(15 - index) +: 8] = data_in[8*index +: 8];
                        index <= index + 4'd1;
                        next_state <= REVERSE;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule