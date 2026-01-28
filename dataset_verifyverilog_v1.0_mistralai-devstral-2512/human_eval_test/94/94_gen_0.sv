module PrimeDigitSum(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr_0,
    input [15:0] arr_1,
    input [15:0] arr_2,
    input [15:0] arr_3,
    input [15:0] arr_4,
    input [15:0] arr_5,
    input [15:0] arr_6,
    input [15:0] arr_7,
    input [15:0] arr_8,
    input [15:0] arr_9,
    input [15:0] arr_10,
    input [15:0] arr_11,
    input [15:0] arr_12,
    input [15:0] arr_13,
    input [15:0] arr_14,
    input [15:0] arr_15,
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SCAN = 4'd1;
    localparam [3:0] CHECK_PRIME = 4'd2;
    localparam [3:0] UPDATE_MAX = 4'd3;
    localparam [3:0] DIGIT_SUM = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] index;
    reg [15:0] current_num;
    reg [15:0] max_prime;
    reg [15:0] digit_sum;
    reg [15:0] d;
    reg is_prime;
    reg [15:0] temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd400;

    // Array selection
    always @(*) begin
        case (index)
            4'd0: current_num = arr_0;
            4'd1: current_num = arr_1;
            4'd2: current_num = arr_2;
            4'd3: current_num = arr_3;
            4'd4: current_num = arr_4;
            4'd5: current_num = arr_5;
            4'd6: current_num = arr_6;
            4'd7: current_num = arr_7;
            4'd8: current_num = arr_8;
            4'd9: current_num = arr_9;
            4'd10: current_num = arr_10;
            4'd11: current_num = arr_11;
            4'd12: current_num = arr_12;
            4'd13: current_num = arr_13;
            4'd14: current_num = arr_14;
            4'd15: current_num = arr_15;
            default: current_num = 16'd0;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            max_prime <= 16'd0;
            digit_sum <= 16'd0;
            d <= 16'd0;
            is_prime <= 1'b0;
            temp <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        index <= 4'd0;
                        max_prime <= 16'd0;
                        next_state <= SCAN;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        next_state <= CHECK_PRIME;
                    end else if (max_prime > 16'd0) begin
                        temp <= max_prime;
                        next_state <= DIGIT_SUM;
                    end else begin
                        result <= 16'd0;
                        next_state <= DONE_STATE;
                    end
                end

                CHECK_PRIME: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_num <= 16'd1) begin
                        is_prime <= 1'b0;
                        next_state <= UPDATE_MAX;
                    end else if (d == 16'd0) begin
                        d <= 16'd2;
                        is_prime <= 1'b1;
                    end else if (d <= 16'd256 && d < current_num) begin
                        if (current_num % d == 16'd0) begin
                            is_prime <= 1'b0;
                            next_state <= UPDATE_MAX;
                        end else begin
                            d <= d + 16'd1;
                        end
                    end else begin
                        next_state <= UPDATE_MAX;
                    end
                end

                UPDATE_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (is_prime && current_num > max_prime) begin
                        max_prime <= current_num;
                    end
                    d <= 16'd0;
                    index <= index + 4'd1;
                    next_state <= SCAN;
                end

                DIGIT_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (temp == 16'd0) begin
                        result <= digit_sum;
                        next_state <= DONE_STATE;
                    end else begin
                        digit_sum <= digit_sum + (temp % 16'd10);
                        temp <= temp / 16'd10;
                    end
                end

                DONE_STATE: begin
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