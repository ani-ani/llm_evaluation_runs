module bulkheads (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire signed [15:0] x [0:7],
    input wire signed [15:0] y [0:7],
    input wire [31:0] C,
    output reg [7:0] M,
    output reg [31:0] x_bulk [0:99],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_AREA = 3'd1;
    localparam [2:0] COMPUTE_M = 3'd2;
    localparam [2:0] COMPUTE_TARGET = 3'd3;
    localparam [2:0] BINARY_SEARCH = 3'd4;
    localparam [2:0] STORE_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Area computation
    reg signed [63:0] shoelace_sum;
    reg signed [31:0] total_area;
    reg signed [15:0] x_min, x_max;

    // M computation
    reg [7:0] k;
    reg [31:0] target_area;

    // Binary search
    reg signed [31:0] low, high, mid;
    reg [3:0] iter;
    reg signed [31:0] cumulative_area;
    reg signed [31:0] x_result;

    // Edge processing
    reg signed [15:0] y_upper, y_lower;
    reg [7:0] i, j;
    reg signed [15:0] x0, x1, y0, y1;
    reg signed [31:0] edge_area;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            M <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            shoelace_sum <= 64'd0;
            total_area <= 32'd0;
            x_min <= 16'd0;
            x_max <= 16'd0;
            k <= 8'd0;
            target_area <= 32'd0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            iter <= 4'd0;
            cumulative_area <= 32'd0;
            x_result <= 32'd0;
            y_upper <= 16'd0;
            y_lower <= 16'd0;
            i <= 8'd0;
            j <= 8'd0;
            x0 <= 16'd0;
            x1 <= 16'd0;
            y0 <= 16'd0;
            y1 <= 16'd0;
            edge_area <= 32'd0;
            for (j = 0; j < 100; j = j + 1) begin
                x_bulk[j] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_AREA;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_AREA: begin
                    shoelace_sum <= 64'd0;
                    x_min <= x[0];
                    x_max <= x[0];
                    for (i = 0; i < N; i = i + 1) begin
                        j = (i + 1) % N;
                        shoelace_sum <= shoelace_sum + $signed({x[i], 16'd0}) * $signed({y[j], 16'd0}) - $signed({x[j], 16'd0}) * $signed({y[i], 16'd0});
                        if (x[i] < x_min) x_min <= x[i];
                        if (x[i] > x_max) x_max <= x[i];
                    end
                    total_area <= shoelace_sum[63:32];
                    if (shoelace_sum[63]) total_area <= -total_area;
                    next_state <= COMPUTE_M;
                end

                COMPUTE_M: begin
                    if (total_area < C) begin
                        M <= 8'd1;
                        next_state <= DONE_STATE;
                    end else begin
                        M <= total_area / C;
                        if (M > 8'd100) M <= 8'd100;
                        if (M == 8'd1) begin
                            next_state <= DONE_STATE;
                        end else begin
                            k <= 8'd1;
                            next_state <= COMPUTE_TARGET;
                        end
                    end
                end

                COMPUTE_TARGET: begin
                    target_area <= (k * total_area) / M;
                    low <= {x_min, 16'd0};
                    high <= {x_max, 16'd0};
                    iter <= 4'd0;
                    next_state <= BINARY_SEARCH;
                end

                BINARY_SEARCH: begin
                    mid <= (low + high) >> 1;
                    cumulative_area <= 32'd0;
                    y_upper <= 16'd0;
                    y_lower <= 16'd0;
                    for (i = 0; i < N; i = i + 1) begin
                        j = (i + 1) % N;
                        x0 <= x[i];
                        x1 <= x[j];
                        y0 <= y[i];
                        y1 <= y[j];
                        if ((x0 <= mid[31:16] && x1 > mid[31:16]) || (x1 <= mid[31:16] && x0 > mid[31:16])) begin
                            if (x0 == x1) begin
                                edge_area <= 32'd0;
                            end else begin
                                edge_area <= {y0, 16'd0} + (($signed({y1, 16'd0}) - $signed({y0, 16'd0})) * ($signed(mid) - $signed({x0, 16'd0}))) / ($signed({x1, 16'd0}) - $signed({x0, 16'd0}));
                                if (y0 > y1) begin
                                    if (edge_area > y_upper) y_upper <= edge_area[31:16];
                                    if (edge_area < y_lower) y_lower <= edge_area[31:16];
                                end else begin
                                    if (edge_area < y_lower) y_lower <= edge_area[31:16];
                                    if (edge_area > y_upper) y_upper <= edge_area[31:16];
                                end
                            end
                        end
                    end
                    edge_area <= (y_upper - y_lower) * (mid - {x_min, 16'd0});
                    cumulative_area <= cumulative_area + edge_area;
                    if (cumulative_area < target_area) begin
                        low <= mid;
                    end else begin
                        high <= mid;
                    end
                    iter <= iter + 4'd1;
                    if (iter == 4'd16) begin
                        x_result <= (low + high) >> 1;
                        next_state <= STORE_RESULT;
                    end else begin
                        next_state <= BINARY_SEARCH;
                    end
                end

                STORE_RESULT: begin
                    x_bulk[k-1] <= x_result;
                    k <= k + 8'd1;
                    if (k == M) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= COMPUTE_TARGET;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
            end
        end
    end

endmodule