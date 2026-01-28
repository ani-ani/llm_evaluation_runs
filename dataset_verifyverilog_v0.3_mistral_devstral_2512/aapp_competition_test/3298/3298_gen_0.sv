module unsorted_checker(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg done,
    output reg is_unsorted
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    
    reg [1:0] state;
    reg [7:0] arr [0:7];
    reg [3:0] current_len;
    reg [7:0] k;
    reg [7:0] j;
    reg left_ok;
    reg right_ok;
    reg any_sorted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            is_unsorted <= 1'b0;
            current_len <= 4'd0;
            k <= 8'd0;
            j <= 8'd0;
            left_ok <= 1'b1;
            right_ok <= 1'b1;
            any_sorted <= 1'b0;
            arr[0] <= 8'd0;
            arr[1] <= 8'd0;
            arr[2] <= 8'd0;
            arr[3] <= 8'd0;
            arr[4] <= 8'd0;
            arr[5] <= 8'd0;
            arr[6] <= 8'd0;
            arr[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        current_len <= len;
                        arr[0] <= arr_0;
                        arr[1] <= arr_1;
                        arr[2] <= arr_2;
                        arr[3] <= arr_3;
                        arr[4] <= arr_4;
                        arr[5] <= arr_5;
                        arr[6] <= arr_6;
                        arr[7] <= arr_7;
                        any_sorted <= 1'b0;
                        k <= 8'd0;
                    end
                end
                COMPUTE: begin
                    if (k < current_len) begin
                        left_ok <= 1'b1;
                        for (j = 0; j < k; j = j + 1) begin
                            if (arr[j] > arr[k]) begin
                                left_ok <= 1'b0;
                            end
                        end
                        right_ok <= 1'b1;
                        for (j = k + 1; j < current_len; j = j + 1) begin
                            if (arr[j] < arr[k]) begin
                                right_ok <= 1'b0;
                            end
                        end
                        if (left_ok && right_ok) begin
                            any_sorted <= 1'b1;
                        end
                        k <= k + 1;
                    end else begin
                        is_unsorted <= ~any_sorted;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule