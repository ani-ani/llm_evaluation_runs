module digit_validator (
input clk,
input rst_n,
input start,
input [31:0] number,
output reg valid,
output reg done
);
localparam IDLE = 3'd0;
localparam EXTRACT_DIGIT = 3'd1;
localparam UPDATE_COUNTER = 3'd2;
localparam CHECK_COUNT = 3'd3;
localparam DONE_STATE = 3'd4;

reg [2:0] state;
reg [31:0] num_reg;
reg [3:0] digit_counters [9:0];
reg invalid;
reg [2:0] digit_pos;
reg [3:0] current_digit_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        num_reg <= 32'd0;
        invalid <= 1'b0;
        digit_pos <= 3'd0;
        current_digit_reg <= 4'd0;
        digit_counters[9] <= 4'd0;
        digit_counters[8] <= 4'd0;
        digit_counters[7] <= 4'd0;
        digit_counters[6] <= 4'd0;
        digit_counters[5] <= 4'd0;
        digit_counters[4] <= 4'd0;
        digit_counters[3] <= 4'd0;
        digit_counters[2] <= 4'd0;
        digit_counters[1] <= 4'd0;
        digit_counters[0] <= 4'd0;
    end else begin
        if (state == IDLE) begin
            valid <= 1'b0;
            done <= 1'b0;
            if (start) begin
                num_reg <= number;
                invalid <= 1'b0;
                digit_pos <= 3'd0;
                current_digit_reg <= 4'd0;
                state <= EXTRACT_DIGIT;
            end
        end else if (state == EXTRACT_DIGIT) begin
            case (digit_pos)
                0: current_digit_reg <= num_reg % 10;
                1: current_digit_reg <= (num_reg / 10) % 10;
                2: current_digit_reg <= (num_reg / 100) % 10;
                3: current_digit_reg <= (num_reg / 1000) % 10;
                4: current_digit_reg <= (num_reg / 10000) % 10;
                5: current_digit_reg <= (num_reg / 100000) % 10;
                6: current_digit_reg <= (num_reg / 1000000) % 10;
                7: current_digit_reg <= (num_reg / 10000000) % 10;
                default: current_digit_reg <= 4'd0;
            endcase
            state <= UPDATE_COUNTER;
        end else if (state == UPDATE_COUNTER) begin
            digit_counters[current_digit_reg] <= digit_counters[current_digit_reg] + 1;
            state <= CHECK_COUNT;
        end else if (state == CHECK_COUNT) begin
            if (digit_counters[current_digit_reg] > current_digit_reg) begin
                invalid <= 1'b1;
            end
            digit_pos <= digit_pos + 1;
            if (digit_pos < 8) begin
                state <= EXTRACT_DIGIT;
            end else begin
                state <= DONE_STATE;
                valid <= !invalid;
                done <= 1'b1;
            end
        end else if (state == DONE_STATE) begin
            if (!start) begin
                state <= IDLE;
                valid <= 1'b0;
                done <= 1'b0;
            end
        end
    end
endmodule