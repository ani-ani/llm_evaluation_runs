module sum_two_digit_k (
input clk,
input rst_n,
input [2:0] k,
input signed [7:0] arr [0:7],
output reg signed [10:0] result,
output reg done
);

parameter IDLE = 2'd0;
parameter PROCESSING = 2'd1;
parameter DONE = 2'd2;

reg signed [10:0] sum;
reg [2:0] count;
reg [1:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        sum <= 0;
        count <= 0;
    end else begin
        case (state)
            IDLE: state <= PROCESSING;
            PROCESSING: begin
                if (count < k) begin
                    if (arr[count] >= 0) begin
                        if (arr[count] <= 99) begin
                            sum <= sum + arr[count];
                        end
                    end else begin
                        if (-arr[count] <= 99) begin
                            sum <= sum + arr[count];
                        end
                    end
                    count <= count + 1;
                end else begin
                    state <= DONE;
                end
            end
            DONE: state <= DONE;
        endcase
    end
end

assign result = sum;
assign done = (state == DONE);

endmodule