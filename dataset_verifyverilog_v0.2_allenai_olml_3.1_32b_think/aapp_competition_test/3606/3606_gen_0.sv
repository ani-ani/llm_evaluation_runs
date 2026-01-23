module frog_jumps (
input clk,
input rst_n,
input start,
input [2:0] num_plants,
input [3:0] num_jumps,
input [7:0] init_x,
input [7:0] init_y,
input [7:0] plant_x [0:7],
input [7:0] plant_y [0:7],
input [7:0] jump_dir,
output reg [7:0] final_x,
output reg [7:0] final_y,
output reg done,
output reg valid
);

reg [7:0] active_plants;
reg [7:0] current_x, current_y;
reg [3:0] jump_counter;
reg [1:0] state;
reg [3:0] num_jumps_reg;
reg [2:0] num_plants_reg;
reg [7:0] saved_init_x, saved_init_y;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        active_plants <= 8'hFF;
        current_x <= init_x;
        current_y <= init_y;
        jump_counter <= 0;
        state <= 0;
        done <= 0;
        valid <= 0;
        num_jumps_reg <= num_jumps;
        num_plants_reg <= num_plants;
        saved_init_x <= init_x;
        saved_init_y <= init_y;
    end else begin
        if (state == 0) begin
            if (start) begin
                if (num_jumps_reg == 0) begin
                    done <= 1;
                    valid <= 1;
                    state <= 2;
                end else begin
                    state <= 1;
                end
            end
        end else if (state == 1) begin
            if (jump_counter < num_jumps_reg) begin
                jump_counter <= jump_counter + 1;
            end else begin
                state <= 2;
                done <= 1;
                valid <= 1;
            end
        end
    end
end

always_comb begin
    done = (state == 2);
    valid = done;
    final_x = current_x;
    final_y = current_y;
end

endmodule