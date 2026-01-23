module majority_element (
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
    input wire [3:0] n,
    input wire [7:0] x,
    output reg result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] DECIDE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [3:0] count;
    reg [3:0] index;
    reg [7:0] target;
    reg [3:0] array_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            count <= 4'd0;
            index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        target <= x;
                        array_len <= n;
                        count <= 4'd0;
                        index <= 4'd0;
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    if (index < array_len) begin
                        if (get_array_value(index) == target) begin
                            count <= count + 4'd1;
                        end
                        index <= index + 4'd1;
                    end else begin
                        state <= DECIDE;
                    end
                end

                DECIDE: begin
                    if (count > (array_len >> 1)) begin
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

    function [7:0] get_array_value;
        input [3:0] idx;
        begin
            case (idx)
                4'd0: get_array_value = arr_0;
                4'd1: get_array_value = arr_1;
                4'd2: get_array_value = arr_2;
                4'd3: get_array_value = arr_3;
                4'd4: get_array_value = arr_4;
                4'd5: get_array_value = arr_5;
                4'd6: get_array_value = arr_6;
                4'd7: get_array_value = arr_7;
                default: get_array_value = 8'd0;
            endcase
        end
    endfunction

endmodule