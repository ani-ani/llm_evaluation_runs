module multiply_int (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] x,
    input signed [15:0] y,
    output reg signed [31:0] result,
    output reg done
);

parameter IDLE = 2'd0;
parameter PROCESSING = 2'd1;
parameter DONE = 2'd2;

reg [1:0] state;

reg [15:0] x_reg, y_reg;
reg [15:0] x_abs_reg, y_abs_reg;
reg signed [31:0] acc;
reg [15:0] counter;
reg res_sign_reg;
reg done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        x_reg <= 0;
        y_reg <= 0;
        x_abs_reg <= 0;
        y_abs_reg <= 0;
        acc <= 0;
        counter <= 0;
        res_sign_reg <= 0;
        done_reg <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                x_reg <= x;
                y_reg <= y;
                x_abs_reg <= (x < 0) ? -x : x;
                y_abs_reg <= (y < 0) ? -y : y;
                if (y_abs_reg == 0) begin
                    acc <= 32'd0;
                    done_reg <= 1;
                    state <= DONE;
                end else begin
                    res_sign_reg <= (x[15] ^ y[15]);
                    acc <= 32'd0;
                    counter <= y_abs_reg;
                    state <= PROCESSING;
                end
            end else begin
                state <= IDLE;
            end
        end else if (state == PROCESSING) begin
            if (counter > 0) begin
                acc <= acc + x_abs_reg;
                counter <= counter - 1;
                state <= PROCESSING;
            end else begin
                if (res_sign_reg) begin
                    acc <= -acc;
                end
                done_reg <= 1;
                state <= DONE;
            end
        end else if (state == DONE) begin
            state <= DONE;
        end
    end
end

assign result = signed(acc);
assign done = done_reg;

endmodule