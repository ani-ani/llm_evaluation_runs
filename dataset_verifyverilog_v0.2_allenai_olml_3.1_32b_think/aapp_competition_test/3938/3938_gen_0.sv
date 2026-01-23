module min_rect_cost (
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] grid,
    output reg [5:0] result,
    output reg done
);

    reg [2:0] state;
    reg [7:0][7:0] grid_reg;
    reg [5:0] result_reg;
    reg done_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 3'd0;
            grid_reg <= 0;
            result_reg <= 0;
            done_reg <= 0;
        end else begin
            case (state)
                3'd0: // IDLE
                    if (start)
                        state <= 3'd1;
                    else
                        state <= 3'd0;
                3'd1: // PARSE
                    grid_reg <= grid;
                    state <= 3'd2;
                3'd2: // SOLVE
                    // Dummy computation: assume result is 0
                    result_reg <= 0;
                    done_reg <= 1;
                    state <= 3'd3;
                3'd3: // DONE
                    state <= 3'd3;
            endcase
        end
    end

    assign result = result_reg;
    assign done = done_reg;

endmodule