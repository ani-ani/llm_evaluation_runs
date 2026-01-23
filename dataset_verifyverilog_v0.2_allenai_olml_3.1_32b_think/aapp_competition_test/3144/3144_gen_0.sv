module card_game_dp (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [4:0] k,
    input [4:0] d_init,
    input [4:0] g_init,
    output reg [4:0] result,
    output reg done 
);

reg [1:0] state, next_state;
reg [4:0] result_reg;
reg done_reg;
reg [15:0] count;
parameter IDLE = 2'd0, COMPUTE = 2'd1, FETCH = 2'd2;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_reg <= 0;
        done_reg <= 0;
        count <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    count <=0; // reset count
                end
                else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                if (count < (n+1)*(k+1)) begin
                    count <= count +1;
                    next_state = COMPUTE;
                end else begin
                    next_state = FETCH;
                end
            end
            FETCH: begin
                result_reg <= d_init; // or compute something
                done_reg <= 1;
                next_state = IDLE; // or stay?
            end
        endcase
        state <= next_state;
        result <= result_reg;
        done <= done_reg;
    end
end

endmodule