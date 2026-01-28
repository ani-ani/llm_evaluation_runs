module OS_Space_Node_Collector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] x0,
    input wire [63:0] y0,
    input wire [7:0] ax,
    input wire [7:0] ay,
    input wire [63:0] bx,
    input wire [63:0] by,
    input wire [63:0] xs,
    input wire [63:0] ys,
    input wire [63:0] t,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Node storage
    reg [63:0] node_x [0:63];
    reg [63:0] node_y [0:63];

    // Counters and temporary registers
    reg [5:0] node_count;
    reg [5:0] i, j;
    reg [63:0] current_x, current_y;
    reg [63:0] dist_start_to_i;
    reg [63:0] dist_i_to_j;
    reg [63:0] total_cost;
    reg [7:0] max_nodes;
    reg [7:0] temp_nodes;

    // Intermediate registers for absolute difference
    reg [63:0] diff_x, diff_y;
    reg [32:0] abs_diff_x, abs_diff_y;

    // Cycle counter for safety
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd5000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            node_count <= 6'd0;
            i <= 6'd0;
            j <= 6'd0;
            current_x <= 64'd0;
            current_y <= 64'd0;
            dist_start_to_i <= 64'd0;
            dist_i_to_j <= 64'd0;
            total_cost <= 64'd0;
            max_nodes <= 8'd0;
            temp_nodes <= 8'd0;
            diff_x <= 64'd0;
            diff_y <= 64'd0;
            abs_diff_x <= 33'd0;
            abs_diff_y <= 33'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 13'd0;

            // Initialize node arrays
            integer k;
            for (k = 0; k < 64; k = k + 1) begin
                node_x[k] <= 64'd0;
                node_y[k] <= 64'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 13'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= GENERATE;
                        node_count <= 6'd0;
                        current_x <= x0;
                        current_y <= y0;
                        node_x[0] <= x0;
                        node_y[0] <= y0;
                        max_nodes <= 8'd0;
                        cycle_count <= 13'd0;
                    end
                end

                GENERATE: begin
                    if (node_count < 6'd63) begin
                        // Generate next node
                        current_x <= ax * current_x + bx;
                        current_y <= ay * current_y + by;

                        // Check for overflow (coordinates > 2^60)
                        if (current_x > 64'd1152921504606846976 || current_y > 64'd1152921504606846976) begin
                            next_state <= COMPUTE;
                        end else begin
                            node_count <= node_count + 6'd1;
                            node_x[node_count] <= current_x;
                            node_y[node_count] <= current_y;
                        end
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (i <= node_count) begin
                        if (j <= node_count) begin
                            // Calculate distance from start to node i
                            diff_x <= xs - node_x[i];
                            diff_y <= ys - node_y[i];

                            // Absolute difference calculation
                            if (diff_x[63]) begin
                                abs_diff_x <= -diff_x;
                            end else begin
                                abs_diff_x <= diff_x;
                            end

                            if (diff_y[63]) begin
                                abs_diff_y <= -diff_y;
                            end else begin
                                abs_diff_y <= diff_y;
                            end

                            dist_start_to_i <= abs_diff_x + abs_diff_y;

                            // Calculate distance from node i to node j
                            diff_x <= node_x[j] - node_x[i];
                            diff_y <= node_y[j] - node_y[i];

                            if (diff_x[63]) begin
                                abs_diff_x <= -diff_x;
                            end else begin
                                abs_diff_x <= diff_x;
                            end

                            if (diff_y[63]) begin
                                abs_diff_y <= -diff_y;
                            end else begin
                                abs_diff_y <= diff_y;
                            end

                            dist_i_to_j <= abs_diff_x + abs_diff_y;

                            // Total cost
                            total_cost <= dist_start_to_i + dist_i_to_j;

                            // Check if within time budget
                            if (total_cost <= t) begin
                                temp_nodes <= j - i + 8'd1;
                                if (temp_nodes > max_nodes) begin
                                    max_nodes <= temp_nodes;
                                end
                            end

                            // Move to next j
                            if (j == node_count) begin
                                j <= 6'd0;
                                i <= i + 6'd1;
                            end else begin
                                j <= j + 6'd1;
                            end
                        end
                    end else begin
                        next_state <= DONE_STATE;
                        result <= max_nodes;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule