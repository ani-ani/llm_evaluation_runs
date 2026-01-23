module maze_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] grid_size_x,
    input [2:0] grid_size_y,
    input [2:0] start_x,
    input [2:0] start_y,
    input [5:0] max_left,
    input [5:0] max_right,
    input [63:0] grid_data,
    output reg [6:0] result,
    output reg done
);

reg [2:0] grid_size_x_reg, grid_size_y_reg;
reg [2:0] start_x_reg, start_y_reg;
reg [5:0] max_left_reg, max_right_reg;
reg [63:0] grid_data_reg;
reg [6:0] result_reg;
reg done_reg;
reg [2:0] state;
reg [5:0] head, tail;
reg [17:0] queue_data [63:0];
reg [5:0] max_left_visited [7:0][7:0];
reg [5:0] max_right_visited [7:0][7:0];
reg [6:0] reachable_count;

parameter IDLE = 3'b000;
parameter PROCESSING = 3'b001;
parameter DONE = 3'b010;

always @(posedge clk) begin
    if (!rst_n) begin
        grid_size_x_reg <= 3'b000;
        grid_size_y_reg <= 3'b000;
        start_x_reg <= 3'b000;
        start_y_reg <= 3'b000;
        max_left_reg <= 6'b000;
        max_right_reg <= 6'b000;
        state <= IDLE;
        result_reg <= 7'b0000000;
        done_reg <= 1'b0;
        head <= 6'b00000;
        tail <= 6'b00000;
        max_left_visited <= 6'b000000;
        max_right_visited <= 6'b000000;
        reachable_count <= 7'b0000000;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    grid_size_x_reg <= grid_size_x;
                    grid_size_y_reg <= grid_size_y;
                    start_x_reg <= start_x;
                    start_y_reg <= start_y;
                    max_left_reg <= max_left;
                    max_right_reg <= max_right;
                    grid_data_reg <= grid_data;
                    state <= PROCESSING;
                end
            end
            PROCESSING: begin
                state <= DONE;
                done_reg <= 1'b1;
                result_reg <= 7'b0000000;
            end
            DONE: state <= DONE;
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule