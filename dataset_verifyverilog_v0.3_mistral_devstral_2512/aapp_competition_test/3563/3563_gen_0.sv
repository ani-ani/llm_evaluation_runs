module ConvexPolygonLines(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [11:0] x0, x1, x2, x3, x4, x5, x6, x7,
    input wire signed [11:0] y0, y1, y2, y3, y4, y5, y6, y7,
    output reg [3:0] result,
    output reg done
);

    // Parameters
    localparam COORD_WIDTH = 12;
    localparam MAX_N = 8;
    localparam RESULT_WIDTH = 4;
    localparam INF = 4'd15;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_LINES_INIT = 4'd1;
    localparam [3:0] COMPUTE_LINES_INNER = 4'd2;
    localparam [3:0] COMPUTE_LINES_STORE = 4'd3;
    localparam [3:0] COMPUTE_LINES_NEXT = 4'd4;
    localparam [3:0] DP_INIT = 4'd5;
    localparam [3:0] DP_UPDATE_LINES = 4'd6;
    localparam [3:0] DP_UPDATE_MASKS = 4'd7;
    localparam [3:0] DP_UPDATE_NEXT_LINE = 4'd8;
    localparam [3:0] DP_DONE = 4'd9;

    // Internal signals
    reg [3:0] state;
    reg [7:0] i_reg, j_reg, k_reg;
    reg [7:0] line_count;
    reg [7:0] current_line_mask;
    reg [7:0] current_mask;
    reg [7:0] next_mask;
    reg [3:0] dp_current [0:255];
    reg [3:0] dp_next [0:255];
    reg [7:0] line_masks [0:27];
    reg [31:0] cross_product;
    reg [11:0] x_i, y_i, x_j, y_j, x_k, y_k;
    reg [11:0] dx, dy;
    reg [7:0] temp_mask;
    reg line_exists;
    reg [7:0] line_idx;
    reg [3:0] min_result;

    // Coordinate arrays
    reg signed [11:0] x [0:7];
    reg signed [11:0] y [0:7];

    // Initialize coordinates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x[0] <= 12'd0; x[1] <= 12'd0; x[2] <= 12'd0; x[3] <= 12'd0;
            x[4] <= 12'd0; x[5] <= 12'd0; x[6] <= 12'd0; x[7] <= 12'd0;
            y[0] <= 12'd0; y[1] <= 12'd0; y[2] <= 12'd0; y[3] <= 12'd0;
            y[4] <= 12'd0; y[5] <= 12'd0; y[6] <= 12'd0; y[7] <= 12'd0;
        end else begin
            x[0] <= x0; x[1] <= x1; x[2] <= x2; x[3] <= x3;
            x[4] <= x4; x[5] <= x5; x[6] <= x6; x[7] <= x7;
            y[0] <= y0; y[1] <= y1; y[2] <= y2; y[3] <= y3;
            y[4] <= y4; y[5] <= y5; y[6] <= y6; y[7] <= y7;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            k_reg <= 8'd0;
            line_count <= 8'd0;
            current_line_mask <= 8'd0;
            current_mask <= 8'd0;
            next_mask <= 8'd0;
            line_exists <= 1'b0;
            line_idx <= 8'd0;
            min_result <= 4'd0;

            // Initialize DP arrays
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                dp_current[i] <= INF;
                dp_next[i] <= INF;
            end

            // Initialize line masks
            for (i = 0; i < 28; i = i + 1) begin
                line_masks[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_LINES_INIT;
                        i_reg <= 8'd0;
                        j_reg <= 8'd1;
                        line_count <= 8'd0;
                    end
                end

                COMPUTE_LINES_INIT: begin
                    x_i <= x[i_reg];
                    y_i <= y[i_reg];
                    x_j <= x[j_reg];
                    y_j <= y[j_reg];
                    dx <= x_j - x_i;
                    dy <= y_j - y_i;
                    current_line_mask <= 8'd0;
                    current_line_mask[i_reg] <= 1'b1;
                    current_line_mask[j_reg] <= 1'b1;
                    k_reg <= 8'd0;
                    state <= COMPUTE_LINES_INNER;
                end

                COMPUTE_LINES_INNER: begin
                    if (k_reg < n && k_reg != i_reg && k_reg != j_reg) begin
                        x_k <= x[k_reg];
                        y_k <= y[k_reg];
                        cross_product <= (dx * (y_k - y_i)) - (dy * (x_k - x_i));
                        if (cross_product == 32'd0) begin
                            current_line_mask[k_reg] <= 1'b1;
                        end
                        k_reg <= k_reg + 8'd1;
                    end else begin
                        state <= COMPUTE_LINES_STORE;
                    end
                end

                COMPUTE_LINES_STORE: begin
                    line_exists <= 1'b0;
                    line_idx <= 8'd0;
                    state <= COMPUTE_LINES_NEXT;
                end

                COMPUTE_LINES_NEXT: begin
                    if (line_idx < line_count && !line_exists) begin
                        if (line_masks[line_idx] == current_line_mask) begin
                            line_exists <= 1'b1;
                        end
                        line_idx <= line_idx + 8'd1;
                    end else begin
                        if (!line_exists && line_count < 28) begin
                            line_masks[line_count] <= current_line_mask;
                            line_count <= line_count + 8'd1;
                        end
                        j_reg <= j_reg + 8'd1;
                        if (j_reg < n) begin
                            state <= COMPUTE_LINES_INIT;
                        end else begin
                            i_reg <= i_reg + 8'd1;
                            if (i_reg < n - 1) begin
                                j_reg <= i_reg + 8'd1;
                                state <= COMPUTE_LINES_INIT;
                            end else begin
                                state <= DP_INIT;
                                current_mask <= 8'd0;
                            end
                        end
                    end
                end

                DP_INIT: begin
                    dp_current[0] <= 4'd0;
                    current_mask <= 8'd0;
                    line_idx <= 8'd0;
                    state <= DP_UPDATE_LINES;
                end

                DP_UPDATE_LINES: begin
                    if (line_idx < line_count) begin
                        temp_mask <= line_masks[line_idx];
                        state <= DP_UPDATE_MASKS;
                    end else begin
                        state <= DP_DONE;
                    end
                end

                DP_UPDATE_MASKS: begin
                    if (current_mask < 256) begin
                        if (dp_current[current_mask] != INF) begin
                            next_mask <= current_mask | temp_mask;
                            if (dp_next[next_mask] > dp_current[current_mask] + 4'd1) begin
                                dp_next[next_mask] <= dp_current[current_mask] + 4'd1;
                            end
                        end
                        current_mask <= current_mask + 8'd1;
                    end else begin
                        // Copy dp_next to dp_current
                        integer i;
                        for (i = 0; i < 256; i = i + 1) begin
                            dp_current[i] <= dp_next[i];
                        end
                        line_idx <= line_idx + 8'd1;
                        current_mask <= 8'd0;
                        state <= DP_UPDATE_LINES;
                    end
                end

                DP_DONE: begin
                    min_result <= dp_current[(1 << n) - 1];
                    result <= min_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule