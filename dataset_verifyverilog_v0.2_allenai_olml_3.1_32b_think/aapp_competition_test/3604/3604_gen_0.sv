module max_clique_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [31:0] d,
    input [7:0][31:0] x_coords,
    input [7:0][31:0] y_coords,
    output reg [2:0] size,
    output reg [7:0] sensor_indices [7:0],
    output reg done
);

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] best_size;
    reg [7:0] best_indices [7:0];
    reg done_reg;

    parameter IDLE = 3'd0;
    parameter COMPUTE = 3'd1;
    parameter DONE_STATE = 3'd2;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            best_size <= 3'd0;
            best_indices <= 8'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            if (state == DONE_STATE) begin
                done_reg <= 1'b1;
            end
        end
    end

    always @(*) begin
        next_state = state;
        if (state == IDLE) begin
            if (start) begin
                next_state = COMPUTE;
            end
        end
        if (state == COMPUTE) begin
            next_state = DONE_STATE;
        end
    end

    assign size = best_size;
    assign sensor_indices = best_indices;
    assign done = done_reg;

endmodule