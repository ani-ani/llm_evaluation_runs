module find_remainder (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [2:0] arr_len,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    reg [7:0] reg_n;
    reg [7:0] reg_arr [0:7];
    reg [2:0] reg_arr_len;
    reg [7:0] acc;
    reg [2:0] index;
    reg [1:0] phase;
    reg [2:0] state;
    reg [7:0] new_acc;
    reg [7:0] temp;
    reg [7:0] result_reg;
    reg done_reg;

    localparam IDLE = 3'b000;
    localparam PROCESSING = 3'b001;
    localparam DONE = 3'b010;

    initial begin
        state <= IDLE;
        reg_n <= 8'd0;
        reg_arr <= 8'd0;
        reg_arr_len <= 3'd0;
        acc <= 8'd1;
        index <= 3'd0;
        phase <= 2'd0;
        done_reg <= 1'b0;
        result_reg <= 8'd0;
        new_acc <= 8'd0;
        temp <= 8'd0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            reg_n <= 8'd0;
            reg_arr <= 8'd0;
            reg_arr_len <= 3'd0;
            acc <= 8'd1;
            index <= 3'd0;
            phase <= 2'd0;
            done_reg <= 1'b0;
            result_reg <= 8'd0;
            new_acc <= 8'd0;
            temp <= 8'd0;
        end else begin
            if (state == IDLE) begin
                if (start) begin
                    state <= PROCESSING;
                    reg_n <= n;
                    reg_arr <= arr;
                    reg_arr_len <= arr_len;
                    acc <= 8'd1;
                    index <= 3'd0;
                    phase <= 2'd0;
                    done_reg <= 1'b0;
                    result_reg <= 8'd0;
                end
            end else if (state == PROCESSING) begin
                if (phase == 2'd0) begin
                    if (reg_arr_len == 3'd0) begin
                        phase <= 2'd1;
                    end else begin
                        if (reg_n == 1) begin
                            temp = 8'd0;
                        end else begin
                            if (reg_arr[index] < reg_n) begin
                                temp = reg_arr[index];
                            end else begin
                                temp = reg_arr[index] - reg_n;
                            end
                        end
                    end
                    phase <= 2'd1;
                end else if (phase == 2'd1) begin
                    if (reg_n == 1) begin
                        new_acc = 8'd0;
                    end else begin
                        new_acc = (acc * temp) % reg_n;
                    end
                    phase <= 2'd2;
                end else if (phase == 2'd2) begin
                    acc <= new_acc;
                    index <= index + 3'd1;
                    if (index < reg_arr_len) begin
                        phase <= 2'd0;
                    end else begin
                        state <= DONE;
                        result_reg <= acc;
                        done_reg <= 1'b1;
                    end
                end
            end else if (state == DONE) begin
                done_reg <= done_reg;
            end
        end
    end

    assign result = result_reg;
    assign done = done_reg;

endmodule