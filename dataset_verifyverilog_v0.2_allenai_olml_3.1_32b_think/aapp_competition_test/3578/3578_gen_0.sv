module airline_review_opt (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [2:0] num_req_edges,
    input [2:0] num_add_edges,
    input [3:0][7:0] req_edges_data,
    input [7:0][7:0] add_edges_data,
    output reg [23:0] min_cost,
    output reg done
);

    reg [2:0] state;
    reg [23:0] result;
    reg done_reg;

    parameter IDLE = 3'b0, PRECOMP = 3'b1, DP = 3'b2, DONE = 3'b3;

    always @(negedge rst_n) begin
        state <= IDLE;
        done_reg <= 0;
        result <= 0;
    end

    always @(posedge clk) begin
        if (state == IDLE) begin
            if (start) state <= PRECOMP;
        end else if (state == PRECOMP) begin
            state <= DP;
        end else if (state == DP) begin
            result <= 24'b0;
            done_reg <= 1;
            state <= DONE;
        end
    end

    assign done = done_reg;
    assign min_cost = result;

endmodule