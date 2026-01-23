module badge_connectivity (
input clk,
input rst_n,
input start,
input [2:0] start_room,
input [2:0] dest_room,
input [5:0] num_locks,
input [15:0] badge_min,
input [15:0] badge_max,
input [2:0] lock_from,
input [2:0] lock_to,
input [15:0] lock_range_min,
input [15:0] lock_range_max,
input lock_load,
input lock_next,
output reg [31:0] valid_badge_count,
output reg done,
output reg error
);

reg [31:0] valid_count;
reg done_reg;
reg error_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_count <= 0;
        done_reg <= 0;
        error_reg <= 0;
    end else begin
        if (start_room == dest_room) begin
            valid_count <= max(badge_max, 0) - max(badge_min, 0) + 1;
            done_reg <= 1;
            error_reg <= 0;
        end else begin
            valid_count <= 0;
            done_reg <= 1;
            error_reg <= 1;
        end
    end
end

assign valid_badge_count = valid_count;
assign done = done_reg;
assign error = error_reg;

endmodule