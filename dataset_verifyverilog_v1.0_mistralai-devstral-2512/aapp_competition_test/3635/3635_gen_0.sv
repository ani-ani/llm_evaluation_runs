module BananaBriefcase(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [15:0] arr [0:15],
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_PREFIX = 3'd1;
    localparam [2:0] FIND_MAX_K = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Prefix sums
    reg [15:0] prefix [0:15];
    reg [3:0] prefix_idx;

    // Main computation variables
    reg [3:0] first_len;
    reg [3:0] current_idx;
    reg [15:0] current_sum;
    reg [15:0] min_sum;
    reg [3:0] k_count;
    reg [3:0] max_k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            prefix_idx <= 4'd0;
            first_len <= 4'd0;
            current_idx <= 4'd0;
            current_sum <= 16'd0;
            min_sum <= 16'd0;
            k_count <= 4'd0;
            max_k <= 4'd0;

            // Initialize prefix array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                prefix[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_PREFIX;
                        prefix_idx <= 4'd0;
                        prefix[0] <= arr[0];
                    end
                end

                COMPUTE_PREFIX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (prefix_idx < N) begin
                        prefix[prefix_idx] <= arr[prefix_idx];
                        if (prefix_idx > 0) begin
                            prefix[prefix_idx] <= prefix[prefix_idx - 1] + arr[prefix_idx];
                        end
                        prefix_idx <= prefix_idx + 4'd1;
                    end else begin
                        state <= FIND_MAX_K;
                        first_len <= 4'd1;
                        max_k <= 4'd0;
                    end
                end

                FIND_MAX_K: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if we've processed all first segment lengths
                    if (first_len > N) begin
                        state <= FINISH;
                    end else begin
                        // Compute sum of first segment
                        current_sum <= prefix[first_len - 1];
                        if (first_len == 1) begin
                            current_sum <= arr[0];
                        end

                        // Initialize for segment counting
                        min_sum <= current_sum;
                        current_idx <= first_len;
                        k_count <= 4'd1;

                        // Find maximum segments for this first_len
                        while (current_idx < N && k_count < 16) begin
                            // Find smallest j where sum(idx...j) >= min_sum
                            reg [3:0] j;
                            reg [15:0] segment_sum;
                            reg found;

                            j <= current_idx;
                            found <= 1'b0;
                            while (j < N && !found) begin
                                segment_sum <= prefix[j];
                                if (current_idx > 0) begin
                                    segment_sum <= prefix[j] - prefix[current_idx - 1];
                                end

                                if (segment_sum >= min_sum) begin
                                    found <= 1'b1;
                                    min_sum <= segment_sum;
                                    k_count <= k_count + 4'd1;
                                    current_idx <= j + 4'd1;
                                end else begin
                                    j <= j + 4'd1;
                                end
                            end

                            if (!found) begin
                                j <= N;
                            end
                        end

                        // Update max_k if current k_count is better
                        if (k_count > max_k) begin
                            max_k <= k_count;
                        end

                        // Move to next first segment length
                        first_len <= first_len + 4'd1;
                    end

                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= max_k;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule