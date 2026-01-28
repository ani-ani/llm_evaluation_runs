module spot #(
    parameter NUM_TOYS = 2,
    parameter NUM_TREES = 1,
    parameter signed [15:0] TOY_X [0:NUM_TOYS-1] = '{10, 10},
    parameter signed [15:0] TOY_Y [0:NUM_TOYS-1] = '{0, 10},
    parameter signed [15:0] TREE_X [0:NUM_TREES-1] = '{9},
    parameter signed [15:0] TREE_Y [0:NUM_TREES-1] = '{1}
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg [31:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT_TREES = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] UPDATE_MAX = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    reg [2:0] state;
    reg [31:0] max_leash;
    reg [31:0] current_leash;
    reg [7:0] toy_idx;
    reg [7:0] tree_idx;
    reg [7:0] wrap_count;
    reg [7:0] sort_pass;
    reg [7:0] sorted_tree_idx [0:3];

    function automatic [31:0] sqrt32(input [31:0] val);
        reg [31:0] res;
        reg [31:0] x;
        reg [31:0] last_x;
        reg [31:0] diff;
        reg [31:0] temp;
        reg [31:0] count;
        res = 32'd0;
        x = val;
        last_x = 32'd0;
        count = 32'd0;
        while (count < 32'd16) begin
            last_x = x;
            temp = x * x;
            if (temp > val) begin
                x = x - (temp - val) / (2 * x);
            end else begin
                x = x + (val - temp) / (2 * x);
            end
            diff = last_x - x;
            if (diff < 0) begin
                diff = -diff;
            end
            if (diff < 32'd1) begin
                res = x;
                count = 32'd16;
            end
            count = count + 32'd1;
        end
        sqrt32 = res;
    endfunction

    function automatic [31:0] distance(input signed [15:0] x1, input signed [15:0] y1,
                                       input signed [15:0] x2, input signed [15:0] y2);
        reg signed [31:0] dx;
        reg signed [31:0] dy;
        reg [31:0] sq;
        dx = (x2 - x1);
        dy = (y2 - y1);
        sq = (dx * dx) + (dy * dy);
        distance = sqrt32(sq << 16);
    endfunction

    function automatic angle_less(input signed [15:0] tx, input signed [15:0] ty,
                                  input signed [15:0] ox, input signed [15:0] oy);
        reg signed [31:0] cross;
        cross = tx * oy - ty * ox;
        angle_less = (cross < 0);
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            max_leash <= 32'd0;
            current_leash <= 32'd0;
            toy_idx <= 8'd0;
            tree_idx <= 8'd0;
            wrap_count <= 8'd0;
            sort_pass <= 8'd0;
            sorted_tree_idx[0] <= 8'd0;
            sorted_tree_idx[1] <= 8'd1;
            sorted_tree_idx[2] <= 8'd2;
            sorted_tree_idx[3] <= 8'd3;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= (NUM_TREES > 1) ? SORT_TREES : COMPUTE;
                        toy_idx <= 8'd0;
                        max_leash <= 32'd0;
                        done <= 1'b0;
                    end
                end

                SORT_TREES: begin
                    if (NUM_TREES > 1 && sort_pass < NUM_TREES - 1) begin
                        if (tree_idx < NUM_TREES - 1 - sort_pass) begin
                            if (!angle_less(TREE_X[sorted_tree_idx[tree_idx]], TREE_Y[sorted_tree_idx[tree_idx]],
                                           TREE_X[sorted_tree_idx[tree_idx + 1]], TREE_Y[sorted_tree_idx[tree_idx + 1]])) begin
                                sorted_tree_idx[tree_idx] <= sorted_tree_idx[tree_idx + 1];
                                sorted_tree_idx[tree_idx + 1] <= sorted_tree_idx[tree_idx];
                            end
                            tree_idx <= tree_idx + 1;
                        end else begin
                            sort_pass <= sort_pass + 1;
                            tree_idx <= 8'd0;
                        end
                    end else begin
                        state <= COMPUTE;
                        tree_idx <= 8'd0;
                    end
                end

                COMPUTE: begin
                    current_leash <= 32'd0;
                    wrap_count <= 8'd0;
                    tree_idx <= 8'd0;
                    state <= UPDATE_MAX;
                end

                UPDATE_MAX: begin
                    if (tree_idx < NUM_TREES) begin
                        if (angle_less(TREE_X[sorted_tree_idx[tree_idx]], TREE_Y[sorted_tree_idx[tree_idx]],
                                      TOY_X[toy_idx], TOY_Y[toy_idx])) begin
                            if (wrap_count == 0) begin
                                current_leash <= current_leash + distance(16'sd0, 16'sd0,
                                    TREE_X[sorted_tree_idx[tree_idx]], TREE_Y[sorted_tree_idx[tree_idx]]);
                            end else begin
                                current_leash <= current_leash + distance(
                                    TREE_X[sorted_tree_idx[tree_idx - 1]], TREE_Y[sorted_tree_idx[tree_idx - 1]],
                                    TREE_X[sorted_tree_idx[tree_idx]], TREE_Y[sorted_tree_idx[tree_idx]]);
                            end
                            wrap_count <= wrap_count + 1;
                        end
                        tree_idx <= tree_idx + 1;
                    end else begin
                        if (wrap_count > 0) begin
                            current_leash <= current_leash + distance(
                                TREE_X[sorted_tree_idx[wrap_count - 1]], TREE_Y[sorted_tree_idx[wrap_count - 1]],
                                TOY_X[toy_idx], TOY_Y[toy_idx]);
                        end else begin
                            current_leash <= distance(16'sd0, 16'sd0, TOY_X[toy_idx], TOY_Y[toy_idx]);
                        end
                        if (current_leash > max_leash) begin
                            max_leash <= current_leash;
                        end
                        if (toy_idx < NUM_TOYS - 1) begin
                            toy_idx <= toy_idx + 1;
                            state <= COMPUTE;
                        end else begin
                            state <= FINISHED;
                        end
                    end
                end

                FINISHED: begin
                    result <= max_leash;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule