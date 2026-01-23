module tree_optimizer (input clk, input rst_n, input start, input [2:0] num_nodes, input [7:0] edges [14:0], output reg [2:0] best_diameter, output reg [2:0] remove_edge_u, remove_edge_v, output reg [2:0] add_edge_u, add_edge_v, output reg done);

reg [2:0] state;
reg [3:0] distance [7:0][7:0];
reg [2:0] best_diam, best_remove_u, best_remove_v, best_add_u, best_add_v;
reg [2:0] current_edge_idx;
reg [1:0] component [7:0];
reg [2:0] temp_diam;
reg [2:0] N;
reg [2:0] reg_num_nodes;

localparam IDLE = 3'd0, COMPUTE=3'd1, TRY=3'd2, FIND=3'd3, EVAL=3'd4, UPDATE=3'd5, DONE_STATE=3'd6;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        best_diam <= 3'd0;
        best_remove_u <= 3'd0;
        best_remove_v <= 3'd0;
        best_add_u <= 3'd0;
        best_add_v <= 3'd0;
        done <= 0;
        current_edge_idx <= 0;
        reg_num_nodes <= 3'd0;
        N <= reg_num_nodes;
    end else begin
        if (state == IDLE) begin
            if (start) state <= COMPUTE;
        end else if (state == COMPUTE) begin
            state <= TRY;
        end else if (state == TRY) begin
            state <= FIND;
        end else if (state == FIND) begin
            state <= EVAL;
        end else if (state == EVAL) begin
            state <= UPDATE;
        end else if (state == UPDATE) begin
            state <= DONE_STATE;
        end
    end
end

always @(posedge clk or posedge num_nodes) begin
    if (!rst_n) begin
        reg_num_nodes <= 3'd0;
    end else begin
        reg_num_nodes <= num_nodes;
    end
end

endmodule