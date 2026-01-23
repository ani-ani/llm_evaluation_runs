module find_even_pair (
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
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_COUNT = 2'd1;
    localparam [1:0] STATE_CALC = 2'd2;
    localparam [1:0] STATE_DONE = 2'd3;

    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] odd_count;
    reg [3:0] even_count;
    reg [7:0] current_val;
    reg [15:0] temp_result;
    reg [1:0] calc_step;

    always @(*) begin
        case (idx)
            4'd0: current_val = arr_0;
            4'd1: current_val = arr_1;
            4'd2: current_val = arr_2;
            4'd3: current_val = arr_3;
            4'd4: current_val = arr_4;
            4'd5: current_val = arr_5;
            4'd6: current_val = arr_6;
            4'd7: current_val = arr_7;
            default: current_val = 8'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result <= 16'd0;
            done <= 1'b0;
            idx <= 4'd0;
            odd_count <= 4'd0;
            even_count <= 4'd0;
            temp_result <= 16'd0;
            calc_step <= 2'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= STATE_COUNT;
                        idx <= 4'd0;
                        odd_count <= 4'd0;
                        even_count <= 4'd0;
                    end
                end

                STATE_COUNT: begin
                    if (idx < len) begin
                        if (current_val[0]) begin
                            odd_count <= odd_count + 4'd1;
                        end else begin
                            even_count <= even_count + 4'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        state <= STATE_CALC;
                        calc_step <= 2'd0;
                        temp_result <= 16'd0;
                    end
                end

                STATE_CALC: begin
                    case (calc_step)
                        2'd0: begin
                            temp_result <= odd_count * (odd_count - 4'd1);
                            calc_step <= calc_step + 2'd1;
                        end
                        2'd1: begin
                            temp_result <= temp_result + (even_count * (even_count - 4'd1));
                            calc_step <= calc_step + 2'd1;
                        end
                        2'd2: begin
                            result <= temp_result >> 1;
                            state <= STATE_DONE;
                        end
                        default: begin
                            state <= STATE_DONE;
                        end
                    endcase
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule