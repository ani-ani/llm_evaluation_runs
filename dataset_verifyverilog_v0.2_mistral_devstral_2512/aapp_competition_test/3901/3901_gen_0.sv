module gcd_operations_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CHECK_ONES = 3'b010;
    localparam CHECK_TOTAL_GCD = 3'b011;
    localparam FIND_SHORTEST = 3'b100;
    localparam CALC_RESULT = 3'b101;
    localparam DONE = 3'b110;

    // Registers
    reg [2:0] state;
    reg [7:0] array [0:7];
    reg [7:0] total_gcd;
    reg [3:0] count_ones;
    reg [7:0] min_length;
    reg [2:0] i, j;
    reg [7:0] current_gcd;
    reg [7:0] temp_gcd;

    // GCD function
    function [7:0] compute_gcd;
        input [7:0] a, b;
        reg [7:0] x, y, t;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                t = y;
                y = x % y;
                x = t;
            end
            compute_gcd = x;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            count_ones <= 0;
            total_gcd <= 0;
            min_length <= 8;
            i <= 0;
            j <= 0;
            current_gcd <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        done <= 0;
                    end
                end

                LOAD: begin
                    array[0] <= a_0;
                    array[1] <= a_1;
                    array[2] <= a_2;
                    array[3] <= a_3;
                    array[4] <= a_4;
                    array[5] <= a_5;
                    array[6] <= a_6;
                    array[7] <= a_7;
                    state <= CHECK_ONES;
                end

                CHECK_ONES: begin
                    count_ones = 0;
                    for (integer k = 0; k < 8; k = k + 1) begin
                        if (array[k] == 1) begin
                            count_ones = count_ones + 1;
                        end
                    end
                    state <= CHECK_TOTAL_GCD;
                end

                CHECK_TOTAL_GCD: begin
                    total_gcd = array[0];
                    for (integer k = 1; k < 8; k = k + 1) begin
                        total_gcd = compute_gcd(total_gcd, array[k]);
                    end
                    if (total_gcd != 1) begin
                        result <= 255;
                        state <= DONE;
                    end else if (count_ones > 0) begin
                        result <= 8 - count_ones;
                        state <= DONE;
                    end else begin
                        state <= FIND_SHORTEST;
                        min_length <= 8;
                        i <= 0;
                        j <= 0;
                    end
                end

                FIND_SHORTEST: begin
                    if (j == 0) begin
                        current_gcd <= array[i];
                        j <= i + 1;
                    end else begin
                        temp_gcd = compute_gcd(current_gcd, array[j]);
                        if (temp_gcd == 1) begin
                            if ((j - i + 1) < min_length) begin
                                min_length <= j - i + 1;
                            end
                            current_gcd <= temp_gcd;
                        end else begin
                            current_gcd <= temp_gcd;
                        end
                        j <= j + 1;
                        if (j == 8) begin
                            i <= i + 1;
                            j <= 0;
                            if (i == 7) begin
                                state <= CALC_RESULT;
                            end
                        end
                    end
                end

                CALC_RESULT: begin
                    result <= (min_length - 1) + 7;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule