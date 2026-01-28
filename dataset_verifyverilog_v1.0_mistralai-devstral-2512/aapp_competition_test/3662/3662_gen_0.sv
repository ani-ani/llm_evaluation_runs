module tree_pairing(
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    input [13:0] L,
    input [4:0] W,
    input [13:0] pos [0:31],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SORT = 4'd1;
    localparam [3:0] COMPUTE_TX = 4'd2;
    localparam [3:0] CALC_LOOP = 4'd3;
    localparam [3:0] CALC_STRAIGHT_1 = 4'd4;
    localparam [3:0] CALC_STRAIGHT_2 = 4'd5;
    localparam [3:0] CALC_DIST_1 = 4'd6;
    localparam [3:0] WAIT_SQRT_1 = 4'd7;
    localparam [3:0] CALC_DIST_2 = 4'd8;
    localparam [3:0] WAIT_SQRT_2 = 4'd9;
    localparam [3:0] COMPARE_AND_ADD = 4'd10;
    localparam [3:0] DONE_STATE = 4'd11;

    // Internal registers
    reg [3:0] state;
    reg [4:0] i, j;
    reg [13:0] p_arr [0:31];
    reg [13:0] Tx [0:15];
    reg [31:0] total_cost;
    reg [31:0] sqrt_in;
    reg [15:0] sqrt_out;
    reg [15:0] dist1, dist2;
    reg [15:0] straight1, straight2;
    reg [15:0] cost1, cost2;
    reg [15:0] min_cost;
    reg [13:0] diff1, diff2;
    reg [13:0] temp_pos;
    reg swap_flag;

    // Sqrt module signals
    reg [31:0] sqrt_val;
    reg [15:0] sqrt_result;
    reg [4:0] sqrt_cycle;
    reg sqrt_start;
    reg sqrt_busy;

    // Sqrt calculation using binary search
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sqrt_busy <= 1'b0;
            sqrt_cycle <= 5'd0;
            sqrt_result <= 16'd0;
        end else if (sqrt_start) begin
            sqrt_busy <= 1'b1;
            sqrt_cycle <= 5'd0;
            sqrt_result <= 16'd0;
        end else if (sqrt_busy) begin
            if (sqrt_cycle < 16) begin
                sqrt_result <= sqrt_result + (sqrt_val >= (sqrt_result + 16'd1) * (sqrt_result + 16'd1)) ? 16'd1 : 16'd0;
                sqrt_cycle <= sqrt_cycle + 5'd1;
            end else begin
                sqrt_busy <= 1'b0;
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            total_cost <= 32'd0;
            i <= 5'd0;
            j <= 5'd0;
            swap_flag <= 1'b0;
            sqrt_start <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize array
                        for (i = 0; i < 32; i = i + 1) begin
                            p_arr[i] <= pos[i];
                        end
                        state <= SORT;
                        i <= 5'd0;
                        j <= 5'd0;
                    end
                end

                SORT: begin
                    if (j < 31) begin
                        if (p_arr[j] > p_arr[j + 1]) begin
                            temp_pos <= p_arr[j];
                            p_arr[j] <= p_arr[j + 1];
                            p_arr[j + 1] <= temp_pos;
                            swap_flag <= 1'b1;
                        end
                        j <= j + 5'd1;
                    end else begin
                        if (swap_flag) begin
                            swap_flag <= 1'b0;
                            j <= 5'd0;
                        end else begin
                            state <= COMPUTE_TX;
                            i <= 5'd0;
                            j <= 5'd0;
                        end
                    end
                end

                COMPUTE_TX: begin
                    if (i < N / 2) begin
                        if (N / 2 - 1 == 0) begin
                            Tx[i] <= 14'd0;
                        end else begin
                            Tx[i] <= (i * L) / (N / 2 - 1);
                        end
                        i <= i + 5'd1;
                    end else begin
                        state <= CALC_LOOP;
                        i <= 5'd0;
                        j <= 5'd0;
                        total_cost <= 32'd0;
                    end
                end

                CALC_LOOP: begin
                    if (i < N / 2) begin
                        j <= 5'd0;
                        state <= CALC_STRAIGHT_1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                CALC_STRAIGHT_1: begin
                    diff1 <= (p_arr[2 * i] > Tx[i]) ? (p_arr[2 * i] - Tx[i]) : (Tx[i] - p_arr[2 * i]);
                    straight1 <= diff1 << 2;
                    state <= CALC_STRAIGHT_2;
                end

                CALC_STRAIGHT_2: begin
                    diff2 <= (p_arr[2 * i + 1] > Tx[i]) ? (p_arr[2 * i + 1] - Tx[i]) : (Tx[i] - p_arr[2 * i + 1]);
                    straight2 <= diff2 << 2;
                    state <= CALC_DIST_1;
                end

                CALC_DIST_1: begin
                    sqrt_val <= (diff1 * diff1 + W * W) << 4;
                    sqrt_start <= 1'b1;
                    state <= WAIT_SQRT_1;
                end

                WAIT_SQRT_1: begin
                    if (!sqrt_busy) begin
                        dist1 <= sqrt_result;
                        state <= CALC_DIST_2;
                    end
                end

                CALC_DIST_2: begin
                    sqrt_val <= (diff2 * diff2 + W * W) << 4;
                    sqrt_start <= 1'b1;
                    state <= WAIT_SQRT_2;
                end

                WAIT_SQRT_2: begin
                    if (!sqrt_busy) begin
                        dist2 <= sqrt_result;
                        state <= COMPARE_AND_ADD;
                    end
                end

                COMPARE_AND_ADD: begin
                    cost1 <= straight1 + dist2;
                    cost2 <= dist1 + straight2;
                    min_cost <= (cost1 < cost2) ? cost1 : cost2;
                    total_cost <= total_cost + min_cost;
                    i <= i + 5'd1;
                    state <= CALC_LOOP;
                end

                DONE_STATE: begin
                    result <= total_cost[15:0];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule