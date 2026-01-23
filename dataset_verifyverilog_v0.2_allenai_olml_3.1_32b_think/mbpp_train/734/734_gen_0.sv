module sum_of_products (
    input clk,
    input rst_n,
    input start,
    input [7:0] array_size,
    input [7:0] arr [0:7],
    output reg [31:0] result,
    output reg done
);

parameter IDLE = 2'd0, PROCESSING = 2'd1, DONE = 2'd2;

reg [1:0] state;
reg [7:0] reg_array_size;
reg [7:0] reg_arr [7:0];
reg [31:0] total, res;
reg [7:0] index;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        reg_array_size <= 8'd0;
        reg_arr[0] <= 8'd0;
        reg_arr[1] <= 8'd0;
        reg_arr[2] <= 8'd0;
        reg_arr[3] <= 8'd0;
        reg_arr[4] <= 8'd0;
        reg_arr[5] <= 8'd0;
        reg_arr[6] <= 8'd0;
        reg_arr[7] <= 8'd0;
        total <= 32'd0;
        res <= 32'd0;
        index <= 8'd0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= PROCESSING;
                reg_array_size <= array_size;
                reg_arr[0] <= arr[0];
                reg_arr[1] <= arr[1];
                reg_arr[2] <= arr[2];
                reg_arr[3] <= arr[3];
                reg_arr[4] <= arr[4];
                reg_arr[5] <= arr[5];
                reg_arr[6] <= arr[6];
                reg_arr[7] <= arr[7];
                total <= 32'd0;
                res <= 32'd0;
                if (reg_array_size == 0) index <= 8'd0; else index <= reg_array_size - 1;
            end
        end else if (state == PROCESSING) begin
            if (index >= 0) begin
                total = total + (reg_arr[index] * (1 + res));
                res = reg_arr[index] * (1 + res);
                index = index - 1;
            end else begin
                state <= DONE;
            end
        end
    end
end

assign done = (state == DONE);
assign result = total;
endmodule