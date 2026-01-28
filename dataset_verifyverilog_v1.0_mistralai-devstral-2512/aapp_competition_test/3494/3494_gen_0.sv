module nearest_tree_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire input_valid,
    input wire [3:0] apple_r,
    input wire [3:0] apple_c,
    input wire [63:0] tree_map,
    output reg [7:0] result,
    output reg done,
    output reg [63:0] next_tree_map
);

    reg [7:0] min_dist;
    reg [5:0] i;
    reg [3:0] r, c;
    reg [7:0] current_dist;
    reg [7:0] r_diff, c_diff;
    reg [7:0] r_diff_sq, c_diff_sq;
    reg [7:0] dist;
    reg [63:0] updated_map;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
            next_tree_map <= 64'd0;
            min_dist <= 8'd0;
        end else begin
            if (start && input_valid) begin
                updated_map = tree_map | (1'b1 << (apple_r * 8 + apple_c));
                min_dist = 8'd112;
                for (i = 0; i < 64; i = i + 1) begin
                    r = i[5:3];
                    c = i[2:0];
                    if (tree_map[i]) begin
                        r_diff = (r > apple_r) ? (r - apple_r) : (apple_r - r);
                        c_diff = (c > apple_c) ? (c - apple_c) : (apple_c - c);
                        r_diff_sq = r_diff * r_diff;
                        c_diff_sq = c_diff * c_diff;
                        dist = r_diff_sq + c_diff_sq;
                        if (dist < min_dist) begin
                            min_dist = dist;
                        end
                    end
                end
                result <= min_dist;
                next_tree_map <= updated_map;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule