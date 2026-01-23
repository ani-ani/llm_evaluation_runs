module kth_element (
input clk,
input rst_n,
input start,
input [2:0] k,
input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
output reg [7:0] result,
output reg done
);

reg [7:0] arr_reg [0:7];
reg [2:0] pass_count;
reg [2:0] compare_count;
reg [2:0] k_val;
reg [1:0] state;

localparam IDLE = 2'd0;
localparam SORTING = 2'd1;
localparam DONE = 2'd2;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        arr_reg <= 8'b0;
        pass_count <= 3'd0;
        compare_count <= 3'd0;
        k_val <= 3'd0;
        result <= 8'b0;
        done <= 1'b0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    arr_reg[0] <= arr_0;
                    arr_reg[1] <= arr_1;
                    arr_reg[2] <= arr_2;
                    arr_reg[3] <= arr_3;
                    arr_reg[4] <= arr_4;
                    arr_reg[5] <= arr_5;
                    arr_reg[6] <= arr_6;
                    arr_reg[7] <= arr_7;
                    k_val <= k;
                    state <= SORTING;
                    result <= 8'b0;
                    done <= 1'b0;
                end
            end
            SORTING: begin
                if (compare_count < (7 - pass_count)) begin
                    if (arr_reg[compare_count] > arr_reg[compare_count +1]) begin
                        arr_reg[compare_count] <= arr_reg[compare_count +1];
                        arr_reg[compare_count +1] <= arr_reg[compare_count];
                    end
                    compare_count <= compare_count +1;
                end else begin
                    pass_count <= pass_count +1;
                    compare_count <= 3'd0;
                    if (pass_count == 7) begin
                        state <= DONE;
                        result <= arr_reg[k_val -1];
                        done <= 1'b1;
                    end
                end
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
endmodule