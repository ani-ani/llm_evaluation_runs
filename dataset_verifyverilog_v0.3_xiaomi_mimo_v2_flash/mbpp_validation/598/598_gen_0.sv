module armstrong_check (
    input clk,
    input rst_n,
    input start,
    input [7:0] number,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] COUNT_DIGITS = 3'd1;
    localparam [2:0] EXTRACT_DIGIT = 3'd2;
    localparam [2:0] CALC_POWER    = 3'd3;
    localparam [2:0] ADD_TO_SUM    = 3'd4;
    localparam [2:0] COMPARE       = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    reg [2:0] state;
    reg [7:0] temp_num;
    reg [7:0] sum;
    reg [7:0] digit_count;
    reg [7:0] current_digit;
    reg [7:0] power_result;
    reg [7:0] power_counter;
    reg [7:0] original_number;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            temp_num <= 8'd0;
            sum <= 8'd0;
            digit_count <= 8'd0;
            current_digit <= 8'd0;
            power_result <= 8'd1;
            power_counter <= 8'd0;
            original_number <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        temp_num <= number;
                        original_number <= number;
                        sum <= 8'd0;
                        digit_count <= 8'd0;
                        state <= COUNT_DIGITS;
                    end
                end

                COUNT_DIGITS: begin
                    if (temp_num > 8'd0) begin
                        temp_num <= temp_num / 8'd10;
                        digit_count <= digit_count + 8'd1;
                    end else begin
                        temp_num <= original_number;
                        if (digit_count == 8'd0) begin
                            state <= FINISH;
                        end else begin
                            state <= EXTRACT_DIGIT;
                        end
                    end
                end

                EXTRACT_DIGIT: begin
                    if (temp_num > 8'd0) begin
                        current_digit <= temp_num % 8'd10;
                        temp_num <= temp_num / 8'd10;
                        power_result <= 8'd1;
                        power_counter <= 8'd0;
                        state <= CALC_POWER;
                    end else begin
                        state <= COMPARE;
                    end
                end

                CALC_POWER: begin
                    if (power_counter < digit_count) begin
                        power_result <= power_result * current_digit;
                        power_counter <= power_counter + 8'd1;
                    end else begin
                        state <= ADD_TO_SUM;
                    end
                end

                ADD_TO_SUM: begin
                    sum <= sum + power_result;
                    state <= EXTRACT_DIGIT;
                end

                COMPARE: begin
                    if (original_number == sum) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule