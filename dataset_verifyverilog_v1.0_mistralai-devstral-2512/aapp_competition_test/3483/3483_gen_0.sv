module figurine_stats(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [15:0] weights [0:15],
    output reg [17:0] max_out,
    output reg [17:0] min_out,
    output reg [31:0] distinct_out,
    output reg [31:0] expected_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FIND_MINMAX = 3'd1;
    localparam [2:0] COMPUTE_EXPECTED = 3'd2;
    localparam [2:0] DP_INIT   = 3'd3;
    localparam [2:0] DP_UPDATE = 3'd4;
    localparam [2:0] COUNT_BITS = 3'd5;
    localparam [2:0] FINISH    = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Min/Max tracking
    reg [15:0] current_min, current_max;
    reg [3:0] weight_idx;

    // Expected value computation
    reg signed [31:0] weight_sum;
    reg [3:0] sum_idx;

    // DP for distinct sums
    reg [17:0] dp_sums [0:239999];
    reg [17:0] new_sums [0:239999];
    reg [17:0] current_sum;
    reg [3:0] dp_weight_idx;
    reg [3:0] dp_selection_idx;
    reg [17:0] dp_max_sum;
    reg [31:0] distinct_count;
    reg [3:0] count_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            max_out <= 18'd0;
            min_out <= 18'd0;
            distinct_out <= 32'd0;
            expected_out <= 32'd0;
            current_min <= 16'd65535;
            current_max <= 16'd0;
            weight_idx <= 4'd0;
            weight_sum <= 32'd0;
            sum_idx <= 4'd0;
            dp_weight_idx <= 4'd0;
            dp_selection_idx <= 4'd0;
            dp_max_sum <= 18'd0;
            distinct_count <= 32'd0;
            count_idx <= 4'd0;
            
            // Initialize DP arrays
            integer i;
            for (i = 0; i < 240000; i = i + 1) begin
                dp_sums[i] <= 18'd0;
                new_sums[i] <= 18'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FIND_MINMAX;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_MINMAX: begin
                    if (weight_idx < N) begin
                        if (weights[weight_idx] < current_min) begin
                            current_min <= weights[weight_idx];
                        end
                        if (weights[weight_idx] > current_max) begin
                            current_max <= weights[weight_idx];
                        end
                        weight_idx <= weight_idx + 4'd1;
                        next_state <= FIND_MINMAX;
                    end else begin
                        max_out <= current_max * 18'd4;
                        min_out <= current_min * 18'd4;
                        next_state <= COMPUTE_EXPECTED;
                    end
                end

                COMPUTE_EXPECTED: begin
                    if (sum_idx < N) begin
                        weight_sum <= weight_sum + weights[sum_idx];
                        sum_idx <= sum_idx + 4'd1;
                        next_state <= COMPUTE_EXPECTED;
                    end else begin
                        // Compute expected = (sum * 4) / N in Q16.16
                        // sum * 4 * 65536 / N
                        expected_out <= (weight_sum * 32'd4 * 32'd65536) / N;
                        next_state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    // Initialize DP with first weight
                    dp_sums[weights[0]] <= 18'd1;
                    dp_max_sum <= weights[0];
                    dp_weight_idx <= 4'd1;
                    dp_selection_idx <= 4'd1;
                    next_state <= DP_UPDATE;
                end

                DP_UPDATE: begin
                    if (dp_selection_idx < 4) begin
                        if (dp_weight_idx < N) begin
                            // Update new_sums for current weight
                            integer i;
                            for (i = 0; i <= dp_max_sum; i = i + 1) begin
                                if (dp_sums[i] == 18'd1) begin
                                    current_sum <= i + weights[dp_weight_idx];
                                    if (current_sum > dp_max_sum) begin
                                        dp_max_sum <= current_sum;
                                    end
                                    new_sums[current_sum] <= 18'd1;
                                end
                            end
                            
                            dp_weight_idx <= dp_weight_idx + 4'd1;
                            next_state <= DP_UPDATE;
                        end else begin
                            // Copy new_sums to dp_sums
                            integer i;
                            for (i = 0; i <= dp_max_sum; i = i + 1) begin
                                dp_sums[i] <= new_sums[i];
                                new_sums[i] <= 18'd0;
                            end
                            
                            dp_weight_idx <= 4'd0;
                            dp_selection_idx <= dp_selection_idx + 4'd1;
                            next_state <= DP_UPDATE;
                        end
                    end else begin
                        next_state <= COUNT_BITS;
                    end
                end

                COUNT_BITS: begin
                    if (count_idx <= dp_max_sum) begin
                        if (dp_sums[count_idx] == 18'd1) begin
                            distinct_count <= distinct_count + 32'd1;
                        end
                        count_idx <= count_idx + 4'd1;
                        next_state <= COUNT_BITS;
                    end else begin
                        distinct_out <= distinct_count;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule