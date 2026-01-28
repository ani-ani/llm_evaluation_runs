module sum_of_digits (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] len,
    output reg [15:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] NEXT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [2:0] idx;
    reg [15:0] total_sum;
    reg [7:0] current_val;
    reg [7:0] abs_val;
    reg [7:0] calc_temp;
    reg [2:0] digit_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            idx <= 3'd0;
            total_sum <= 16'd0;
            current_val <= 8'd0;
            abs_val <= 8'd0;
            calc_temp <= 8'd0;
            digit_state <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                        idx <= 3'd0;
                        total_sum <= 16'd0;
                    end
                end

                LOAD: begin
                    if (idx < len) begin
                        case (idx)
                            3'd0: current_val <= arr_0;
                            3'd1: current_val <= arr_1;
                            3'd2: current_val <= arr_2;
                            3'd3: current_val <= arr_3;
                            3'd4: current_val <= arr_4;
                            3'd5: current_val <= arr_5;
                            3'd6: current_val <= arr_6;
                            3'd7: current_val <= arr_7;
                        endcase
                        state <= CALCULATE;
                        digit_state <= 3'd0;
                        calc_temp <= 8'd0;
                        abs_val <= 8'd0;
                    end else begin
                        state <= FINISH;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    case (digit_state)
                        3'd0: begin
                            // Get absolute value
                            if (current_val[7]) begin
                                abs_val <= (~current_val + 8'd1);
                            end else begin
                                abs_val <= current_val;
                            end
                            calc_temp <= current_val;
                            digit_state <= 3'd1;
                        end

                        3'd1: begin
                            // Sum digits of original value (with sign)
                            if (calc_temp >= 8'd10) begin
                                total_sum <= total_sum + {12'd0, calc_temp[3:0]};
                                calc_temp <= calc_temp - 8'd10;
                            end else begin
                                total_sum <= total_sum + {12'd0, calc_temp[3:0]};
                                digit_state <= 3'd2;
                            end
                        end

                        3'd2: begin
                            // Sum digits of absolute value
                            calc_temp <= abs_val;
                            digit_state <= 3'd3;
                        end

                        3'd3: begin
                            // Sum tens digit of absolute value
                            if (abs_val >= 8'd10) begin
                                total_sum <= total_sum + 16'd10;
                                abs_val <= abs_val - 8'd10;
                                digit_state <= 3'd4;
                            end else begin
                                digit_state <= 3'd5;
                            end
                        end

                        3'd4: begin
                            // Sum hundreds digit of absolute value
                            if (abs_val != 8'd0) begin
                                total_sum <= total_sum + {12'd0, abs_val[3:0]};
                            end
                            digit_state <= 3'd5;
                        end

                        3'd5: begin
                            state <= NEXT;
                        end
                    endcase
                end

                NEXT: begin
                    idx <= idx + 3'd1;
                    state <= LOAD;
                end

                FINISH: begin
                    result <= total_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule