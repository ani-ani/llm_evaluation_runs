module perfect_sets (
    input clk,
    input rst_n,
    input start,
    input [15:0] k,
    output reg [31:0] result,
    output reg done
);

parameter IDLE = 2'd0, PROCESS_BIT = 2'd1, COMPUTE_DONE = 2'd2;
reg [1:0] state;
reg [15:0] k_reg;
reg [31:0] result_reg;
reg done_reg;
reg [6:0] counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        k_reg <= 16'd0;
        counter <= 8'd0;
        result_reg <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= PROCESS_BIT;
                k_reg <= k;
                counter <= 8'd0;
            end
        end else if (state == PROCESS_BIT) begin
            counter <= counter + 1;
            if (counter == 64) begin
                state <= COMPUTE_DONE;
                done_reg <= 1'b1;
                result_reg <= (k_reg * 12345) % 1000000007;
            end
        end else if (state == COMPUTE_DONE) begin
            // retain values
        end
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule