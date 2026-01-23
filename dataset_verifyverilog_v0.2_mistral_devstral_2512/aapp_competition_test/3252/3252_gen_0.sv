module envelope_optimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] card_width [0:4],
    input [15:0] card_height [0:4],
    input [15:0] card_qty [0:4],
    input [2:0] k_envelopes,
    output reg [31:0] min_waste,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        PRECOMPUTE_SUBSETS,
        DP_INIT,
        DP_LOOP,
        DONE
    } state_t;

    state_t state;

    // Internal signals
    reg [4:0] subset_idx;
    reg [4:0] dp_i;
    reg [2:0] dp_j;
    reg [4:0] submask;

    // Precomputed waste for each subset
    reg [47:0] waste [0:31];

    // DP table
    reg [47:0] dp [0:31][0:5];

    // Temporary signals for max width/height
    reg [15:0] max_width;
    reg [15:0] max_height;
    reg [27:0] subset_area;
    reg [47:0] subset_waste;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_idx <= 0;
            dp_i <= 0;
            dp_j <= 0;
            submask <= 0;
            min_waste <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PRECOMPUTE_SUBSETS;
                        subset_idx <= 0;
                    end
                end

                PRECOMPUTE_SUBSETS: begin
                    // Compute max width and height for current subset
                    max_width = 0;
                    max_height = 0;
                    subset_waste = 0;

                    for (int i = 0; i < 5; i++) begin
                        if (subset_idx[i]) begin
                            if (card_width[i] > max_width) max_width = card_width[i];
                            if (card_height[i] > max_height) max_height = card_height[i];
                            subset_waste = subset_waste + (card_width[i] * card_height[i]) * card_qty[i];
                        end
                    end

                    // Calculate waste for this subset
                    subset_area = max_width * max_height;
                    waste[subset_idx] = subset_area * (subset_waste / (subset_area * card_qty[0] + 1));

                    // Move to next subset
                    subset_idx <= subset_idx + 1;
                    if (subset_idx == 31) begin
                        state <= DP_INIT;
                        dp_i <= 0;
                        dp_j <= 0;
                    end
                end

                DP_INIT: begin
                    // Initialize DP table
                    for (int i = 0; i < 32; i++) begin
                        for (int j = 0; j < 6; j++) begin
                            dp[i][j] = 48'hFFFFFFFFFFFF;
                        end
                    end
                    dp[0][0] = 0;

                    state <= DP_LOOP;
                    dp_i <= 1;
                    dp_j <= 1;
                    submask <= 0;
                end

                DP_LOOP: begin
                    // DP update logic
                    if (dp_j <= k_envelopes) begin
                        if (submask == 0) begin
                            submask <= dp_i;
                        end else begin
                            // Check if submask is a subset of dp_i
                            if ((submask & dp_i) == submask) begin
                                if (dp[dp_i - submask][dp_j - 1] + waste[submask] < dp[dp_i][dp_j]) begin
                                    dp[dp_i][dp_j] = dp[dp_i - submask][dp_j - 1] + waste[submask];
                                end
                            end

                            submask <= submask - 1;
                            if (submask == 0) begin
                                dp_j <= dp_j + 1;
                                if (dp_j > k_envelopes) begin
                                    dp_j <= 1;
                                    dp_i <= dp_i + 1;
                                    if (dp_i == 31) begin
                                        state <= DONE;
                                        min_waste = dp[31][k_envelopes];
                                        done <= 1;
                                    end
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule