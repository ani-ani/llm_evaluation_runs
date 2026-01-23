module sliding_blocks_solver (
input clk,
input rst_n,
input start,
input [63:0] target_matrix,
input [5:0] initial_r,
input [5:0] initial_c,

output reg [7:0] move_count,
output reg [31:0] move_data,
output reg move_valid,
output reg solve_done,
output reg possible
);

reg [63:0] visited;
reg [5:0] r_pos, c_pos;
reg [3:0] state;
reg [7:0] move_count_reg;
reg [31:0] move_data_reg;
reg move_valid_reg;
reg solve_done_reg;
reg possible_reg;

parameter IDLE = 3'd0;
parameter CHECK_NEIGHBORS = 3'd1;
parameter VERIFY_COMPLETE = 3'd2;
parameter DONE = 3'd3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        move_count_reg <= 8'd0;
        move_data_reg <= 32'd0;
        move_valid_reg <= 1'b0;
        solve_done_reg <= 1'b0;
        possible_reg <= 1'b0;
        r_pos <= initial_r - 1;
        c_pos <= initial_c - 1;
        visited <= 32'd0;
        integer init_pos = (r_pos) * 8 + c_pos;
        visited[init_pos] = 1'b1;
    end else begin
        if (state == IDLE && start) state <= CHECK_NEIGHBORS;
    end
end

always @(*) begin
    if (state == IDLE) begin
        if (start) state <= CHECK_NEIGHBORS;
        move_valid_reg <= 1'b0;
        solve_done_reg <= 1'b0;
        possible_reg <= 1'b0;
    end else if (state == CHECK_NEIGHBORS) state <= VERIFY_COMPLETE;
    else if (state == VERIFY_COMPLETE) begin
        integer total = 0, matched = 0;
        for (int i=0; i<64; i++) begin
            if (target_matrix[i]) begin
                total +=1;
                if (visited[i]) matched +=1;
            end
        end
        if (matched == total) possible_reg <= 1'b1;
        else possible_reg <= 1'b0;
        solve_done_reg <= 1'b1;
        state <= DONE;
    end
end

assign move_count = move_count_reg;
assign move_data = move_data_reg;
assign move_valid = move_valid_reg;
assign solve_done = solve_done_reg;
assign possible = possible_reg;

endmodule