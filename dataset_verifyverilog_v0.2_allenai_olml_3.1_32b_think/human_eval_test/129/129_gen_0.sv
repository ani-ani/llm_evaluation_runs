module minPath(input clk, input rst_n, input start, input [1:0][1:0][7:0] grid, input [3:0] k, output reg [9:0][7:0] result, output reg done);

localparam IDLE = 3'b000;
localparam INIT = 3'b001;
localparam PROCESS_STEP = 3'b010;
localparam CHECK_COMPLETE = 3'b011;
localparam DONE = 3'b100;

reg [2:0] state;
reg [1:0] current_pos;
reg [3:0] current_length;
reg [9:0][7:0] result_reg;
reg done_reg;
reg [4:0] step_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_pos <= 2'b00;
        current_length <=4'b0000;
        result_reg <= 10{{8{{0}}}};
        done_reg <=1'b0;
        step_counter <=5'b00000;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= INIT;
                end else begin
                    state <= IDLE;
                end
            end
            INIT: begin
                reg [7:0] cell00 = grid[0][0];
                reg [7:0] cell01 = grid[0][1];
                reg [7:0] cell10 = grid[1][0];
                reg [7:0] cell11 = grid[1][1];
                reg [7:0] min_val = cell00;
                if (cell01 < min_val) min_val = cell01;
                if (cell10 < min_val) min_val = cell10;
                if (cell11 < min_val) min_val = cell11;
                reg [1:0] start_pos;
                if (grid[0][0] == min_val) start_pos = 2'b00;
                else if (grid[0][1] == min_val) start_pos = 2'b01;
                else if (grid[1][0] == min_val) start_pos = 2'b10;
                else start_pos = 2'b11;
                current_pos <= start_pos;
                current_length <=4'b0001;
                result_reg[0] <= min_val;
                if (k ==4'd1) begin
                    state <= DONE;
                    done_reg <=1'b1;
                end else begin
                    state <= PROCESS_STEP;
                    step_counter <= 19;
                end
            end
            PROCESS_STEP: begin
                if (step_counter ==0) begin
                    reg [1:0] neighbor_coords [1:0];
                    reg [7:0] neighbor_vals [1:0];
                    if (current_pos == 2'b00) begin
                        neighbor_coords[0] = 2'b01; neighbor_vals[0] = grid[0][1];
                        neighbor_coords[1] = 2'b10; neighbor_vals[1] = grid[1][0];
                    end else if (current_pos == 2'b01) begin
                        neighbor_coords[0] = 2'b00; neighbor_vals[0] = grid[0][0];
                        neighbor_coords[1] = 2'b11; neighbor_vals[1] = grid[1][1];
                    end else if (current_pos == 2'b10) begin
                        neighbor_coords[0] = 2'b00; neighbor_vals[0] = grid[0][0];
                        neighbor_coords[1] = 2'b11; neighbor_vals[1] = grid[1][1];
                    end else begin
                        neighbor_coords[0] = 2'b01; neighbor_vals[0] = grid[0][1];
                        neighbor_coords[1] = 2'b10; neighbor_vals[1] = grid[1][0];
                    end
                    reg [1:0] selected_coord;
                    reg [0:0] selected_idx;
                    if (neighbor_vals[0] < neighbor_vals[1]) begin
                        selected_coord = neighbor_coords[0];
                        selected_idx =0;
                    end else if (neighbor_vals[1] < neighbor_vals[0]) begin
                        selected_coord = neighbor_coords[1];
                        selected_idx =1;
                    end else begin
                        if (neighbor_coords[0] < neighbor_coords[1]) begin
                            selected_coord = neighbor_coords[0];
                            selected_idx =0;
                        end else begin
                            selected_coord = neighbor_coords[1];
                            selected_idx =1;
                        end
                    end
                    result_reg[current_length] <= neighbor_vals[selected_idx];
                    current_length <= current_length +1;
                    current_pos <= selected_coord;
                    if (current_length < k) begin
                        step_counter <= 19;
                        state <= PROCESS_STEP;
                    end else begin
                        state <= DONE;
                        done_reg <=1'b1;
                    end
                end else begin
                    step_counter <= step_counter -1;
                    state <= PROCESS_STEP;
                end
            end
            DONE: begin
                state <= DONE;
            end
            default: state <= IDLE;
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule