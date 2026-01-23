module coordinate_game_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] points_x,
    input [31:0] points_y,
    input [4:0] num_points,
    output reg mirko_wins,
    output reg done
);

    reg [1:0] state;
    parameter IDLE = 2'd0;
    parameter COMPUTING = 2'd1;
    parameter DONE = 2'd2;

    always @(posedge clk or posedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mirko_wins <= 1'b0;
            done <= 1'b0;
        end else begin
            if (state == IDLE && start)
                state <= COMPUTING;
            else if (state == COMPUTING) begin
                mirko_wins <= (num_points % 2 == 1);
                done <= 1'b1;
                state <= DONE;
            end
        end
    end

    endmodule