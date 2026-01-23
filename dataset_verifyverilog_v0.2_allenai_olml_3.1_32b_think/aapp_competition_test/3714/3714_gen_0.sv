module crush_game (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] crush,
    output reg [31:0] result,
    output reg done
);

reg [3:0] n_cap;
reg [15:0] crush_cap;
reg [2:0] state;
reg [31:0] result_reg;
reg done_reg;

localparam IDLE = 3'd0, INIT=3'd1, CHECK=3'd2, COMPUTE=3'd3, DONE=3'd4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        n_cap <=4'd0;
        state <= IDLE;
        result_reg <=32'd-1;
        done_reg <=0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= INIT;
                    n_cap <= n;
                end
            end
            INIT: begin
                if (n_cap >4'd16) begin
                    result_reg <=32'd-1;
                    done_reg <=1;
                    state <= DONE;
                end else begin
                    state <= CHECK;
                end
            end
            CHECK: begin
                state <= COMPUTE;
            end
            COMPUTE: begin
                result_reg <=32'd42;
                state <= DONE;
            end
            DONE: begin
                done_reg <=1;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule