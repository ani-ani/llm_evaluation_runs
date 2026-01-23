module card_game_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] hand,
    input [7:0] pile,
    output reg [7:0] result,
    output reg done
);

reg [2:0] state;
reg [7:0] captured_hand, captured_pile;
reg [7:0] result_reg;
reg done_reg;

parameter IDLE = 3'd0, LOAD = 1, CHECK_SEQ = 2, CALC_COST = 3, DONE = 4;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        captured_hand <= 8'b0;
        captured_pile <= 8'b0;
        result_reg <= 8'b0;
        done_reg <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD;
                else state <= IDLE;
            end
            LOAD: begin
                captured_hand <= hand;
                captured_pile <= pile;
                state <= CHECK_SEQ;
            end
            CHECK_SEQ: state <= CALC_COST;
            CALC_COST: state <= DONE;
            DONE: done_reg <= 1;
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule