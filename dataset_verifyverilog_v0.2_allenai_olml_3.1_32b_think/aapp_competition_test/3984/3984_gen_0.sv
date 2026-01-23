module game_winner (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [1:0] result,
    output reg valid,
    output reg done
);

    parameter MAX_LEN = 64;

    reg [7:0] min_char;
    reg [2:0] count;
    reg state;
    reg [1:0] result_reg1, result_reg2;
    reg [2:0] valid_count;

    always @(negedge rst_n) begin
        if (!rst_n) begin
            min_char <= 8'b11111111;
            count <= 3'b000;
            state <= 0;
            result_reg1 <= 2'b00;
            result_reg2 <= 2'b00;
            valid_count <= 3'b000;
        end
    end

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= 1;
                    count <= 3'b000;
                end
            end
            PROCESSING: begin
                if (count < MAX_LEN) begin
                    wire [1:0] result_comb;
                    assign result_comb = (char_in > min_char) ? 2'b01 : 2'b00;

                    min_char <= min(min_char, char_in);
                    count <= count + 1;

                    result_reg1 <= result_comb;

                    if (count == MAX_LEN) begin
                        state <= 2;
                    end else begin
                        state <= 1;
                    end
                end else begin
                    if (state != 2) begin
                        state <= 2;
                    end
                end
            end
            DONE: begin
                if (start) begin
                    state <= 0;
                    count <= 3'b000;
                end
            end
        endcase

        result_reg2 <= result_reg1;

        if (state == 1 && count < MAX_LEN) begin
            valid_count <= count + 2;
        end
        valid <= (valid_count == count);

        done <= (state == 2);
    end

    assign result = (valid) ? result_reg2 : 2'b10;

    endmodule