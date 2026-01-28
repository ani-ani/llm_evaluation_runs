module min_ops_to_all_ones(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] arr [0:15],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COUNT_1S  = 3'd1;
    localparam [2:0] COMPUTE_GCD = 3'd2;
    localparam [2:0] FIND_SUBARRAY = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Intermediate registers
    reg [3:0] count_ones;
    reg [31:0] overall_gcd;
    reg [31:0] current_gcd;
    reg [3:0] min_length;
    reg [3:0] i_reg, j_reg;
    reg [3:0] temp_i, temp_j;

    // GCD computation function
    function [31:0] compute_gcd;
        input [31:0] a, b;
        reg [31:0] x, y, temp;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                temp = y;
                y = x % y;
                x = temp;
            end
            compute_gcd = x;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            count_ones <= 4'd0;
            overall_gcd <= 32'd0;
            current_gcd <= 32'd0;
            min_length <= 4'd16;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            temp_i <= 4'd0;
            temp_j <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COUNT_1S;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNT_1S: begin
                    count_ones <= 4'd0;
                    for (temp_i = 0; temp_i < len; temp_i = temp_i + 1) begin
                        if (arr[temp_i] == 32'd1) begin
                            count_ones <= count_ones + 4'd1;
                        end
                    end

                    if (count_ones > 4'd0) begin
                        result <= len - count_ones;
                        next_state <= FINISH;
                    end else if (len == 4'd0) begin
                        result <= 16'd0;
                        next_state <= FINISH;
                    end else if (len == 4'd1) begin
                        if (arr[0] == 32'd1) begin
                            result <= 16'd0;
                        end else begin
                            result <= 16'd-1;
                        end
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE_GCD;
                    end
                end

                COMPUTE_GCD: begin
                    overall_gcd <= arr[0];
                    for (temp_i = 1; temp_i < len; temp_i = temp_i + 1) begin
                        overall_gcd <= compute_gcd(overall_gcd, arr[temp_i]);
                    end

                    if (overall_gcd != 32'd1) begin
                        result <= 16'd-1;
                        next_state <= FINISH;
                    end else begin
                        min_length <= 4'd16;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        next_state <= FIND_SUBARRAY;
                    end
                end

                FIND_SUBARRAY: begin
                    if (i_reg < len) begin
                        current_gcd <= arr[i_reg];
                        if (current_gcd == 32'd1) begin
                            if (1 < min_length) begin
                                min_length <= 1;
                            end
                        end

                        for (temp_j = i_reg + 1; temp_j < len; temp_j = temp_j + 1) begin
                            current_gcd <= compute_gcd(current_gcd, arr[temp_j]);
                            if (current_gcd == 32'd1) begin
                                if ((temp_j - i_reg + 1) < min_length) begin
                                    min_length <= temp_j - i_reg + 1;
                                end
                                break;
                            end
                        end

                        i_reg <= i_reg + 1;
                        next_state <= FIND_SUBARRAY;
                    end else begin
                        if (min_length == 4'd16) begin
                            result <= 16'd-1;
                        end else begin
                            result <= (min_length - 1) + (len - 1);
                        end
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
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

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = IDLE;
            COUNT_1S: next_state = COUNT_1S;
            COMPUTE_GCD: next_state = COMPUTE_GCD;
            FIND_SUBARRAY: next_state = FIND_SUBARRAY;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule