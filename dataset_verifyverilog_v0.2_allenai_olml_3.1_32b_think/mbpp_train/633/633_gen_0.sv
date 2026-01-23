module pair_xor_sum (input clk, input rst_n, input start, input [2:0] n, input [7:0] arr [0:7], output reg [15:0] result, output reg done);
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [2:0] n_reg;
reg [7:0] arr_reg [0:7];
reg [2:0] i;
reg [2:0] j;
reg [15:0] total;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        n_reg <= 3'b000;
        arr_reg[0] <= 8'b0;
        arr_reg[1] <= 8'b0;
        arr_reg[2] <= 8'b0;
        arr_reg[3] <= 8'b0;
        arr_reg[4] <= 8'b0;
        arr_reg[5] <= 8'b0;
        arr_reg[6] <= 8'b0;
        arr_reg[7] <= 8'b0;
        i <= 3'b000;
        j <= 3'b000;
        total <= 16'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                n_reg <= n;
                arr_reg[0] <= arr[0];
                arr_reg[1] <= arr[1];
                arr_reg[2] <= arr[2];
                arr_reg[3] <= arr[3];
                arr_reg[4] <= arr[4];
                arr_reg[5] <= arr[5];
                arr_reg[6] <= arr[6];
                arr_reg[7] <= arr[7];
                if (n_reg < 2) begin
                    state <= DONE;
                end else begin
                    i <= 3'b000;
                    j <= i + 1;
                    state <= PROCESSING;
                end
            end
        end else if (state == PROCESSING) begin
            if (i < n_reg - 1) begin
                if (j < n_reg) begin
                    total <= total + (arr_reg[i] ^ arr_reg[j]);
                    j <= j + 1;
                end else begin
                    i <= i + 1;
                    j <= i + 1;
                end
            end else begin
                state <= DONE;
            end
        end else if (state == DONE) begin
            // remain in DONE
        end
    end
end
assign result = total;
assign done = (state == DONE);
endmodule