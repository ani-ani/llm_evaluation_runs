module shortest_cycle_finder (input clk, input rst_n, input start, input [3:0] num_nodes, input [255:0] adj_matrix_flat, output reg [3:0] cycle_len, output reg [3:0] cycle_nodes [0:15], output reg done);
reg [2:0] state;
reg [3:0] saved_num_nodes;
reg [255:0] adj_matrix_flat_reg;
reg [4:0] dist [0:15][0:15];
reg [3:0] parent [0:15][0:15];
reg [11:0] m;
reg [11:0] n_cubed;
localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam FLOYD_LOOP = 3'd2;
localparam CHECK_CYCLES = 3'd3;
localparam BACKTRACK = 3'd4;
localparam DONE = 3'd5;
always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        saved_num_nodes <= 4'd0;
        adj_matrix_flat_reg <= 16'd0;
        dist <= 0;
        parent <= 0;
        m <= 0;
        n_cubed <= 0;
        cycle_len <= 4'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= INIT;
                else state <= IDLE;
            end
            INIT: begin
                saved_num_nodes <= num_nodes;
                adj_matrix_flat_reg <= adj_matrix_flat;
                n_cubed <= 16*16*16;
                state <= FLOYD_LOOP;
            end
            FLOYD_LOOP: begin
                if (m < n_cubed) begin
                    m <= m + 1;
                end else begin
                    state <= CHECK_CYCLES;
                end
            end
            CHECK_CYCLES: begin
                state <= BACKTRACK;
            end
            BACKTRACK: begin
                state <= DONE;
            end
            DONE: begin
                done <= 1'b1;
            end
        endcase
    end
end
assign state = state;
assign saved_num_nodes = saved_num_nodes;
assign adj_matrix_flat_reg = adj_matrix_flat_reg;
assign dist = dist;
assign parent = parent;
assign m = m;
assign n_cubed = n_cubed;
assign cycle_len = cycle_len;
assign done = done;
endmodule