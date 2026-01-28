module longest_balanced_parens(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] pieces [0:7],
    input wire [3:0] piece_len [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_METRICS = 3'd1;
    localparam [2:0] SORT_PIECES = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Piece metrics
    reg signed [3:0] net [0:7];
    reg [3:0] max_prefix [0:7];

    // Sorted indices
    reg [2:0] sorted_indices [0:7];

    // DP state
    reg [7:0] mask;
    reg signed [3:0] balance;
    reg [15:0] dp [0:255];
    reg [3:0] dp_balance [0:255];

    // Temporary variables
    reg [7:0] i, j, k;
    reg [3:0] temp_net, temp_max_prefix;
    reg [15:0] temp_length;
    reg signed [3:0] temp_balance;
    reg [7:0] temp_mask;
    reg [15:0] max_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                net[i] <= 4'd0;
                max_prefix[i] <= 4'd0;
                sorted_indices[i] <= 3'd0;
            end

            for (i = 0; i < 256; i = i + 1) begin
                dp[i] <= 16'd0;
                dp_balance[i] <= 4'd0;
            end

            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            temp_net <= 4'd0;
            temp_max_prefix <= 4'd0;
            temp_length <= 16'd0;
            temp_balance <= 4'd0;
            temp_mask <= 8'd0;
            max_result <= 16'd0;
            mask <= 8'd0;
            balance <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_METRICS;
                        i <= 8'd0;
                    end
                end

                COMPUTE_METRICS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute net and max_prefix for each piece
                    if (i < 8) begin
                        temp_net <= 4'd0;
                        temp_max_prefix <= 4'd0;
                        temp_length <= 16'd0;

                        // Calculate net balance
                        for (j = 0; j < piece_len[i]; j = j + 1) begin
                            if (pieces[i][j]) begin
                                temp_net <= temp_net + 4'd1;
                            end else begin
                                temp_net <= temp_net - 4'd1;
                            end
                        end

                        // Calculate max_prefix
                        temp_balance <= 4'd0;
                        temp_max_prefix <= 4'd0;
                        for (j = 0; j < piece_len[i]; j = j + 1) begin
                            if (pieces[i][j]) begin
                                temp_balance <= temp_balance + 4'd1;
                            end else begin
                                temp_balance <= temp_balance - 4'd1;
                            end

                            if (temp_balance >= 4'd0) begin
                                temp_max_prefix <= temp_max_prefix + 4'd1;
                            end else begin
                                j <= piece_len[i]; // break equivalent
                            end
                        end

                        net[i] <= temp_net;
                        max_prefix[i] <= temp_max_prefix;
                        i <= i + 8'd1;
                    end else begin
                        state <= SORT_PIECES;
                        i <= 8'd0;
                        j <= 8'd0;
                    end
                end

                SORT_PIECES: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Simple bubble sort based on criteria
                    if (i < 7) begin
                        if (j < 7 - i) begin
                            // Compare pieces[j] and pieces[j+1]
                            reg should_swap;
                            should_swap <= 1'b0;

                            // Positive net first
                            if (net[j] > 4'd0 && net[j+1] <= 4'd0) begin
                                should_swap <= 1'b1;
                            end else if (net[j] > 4'd0 && net[j+1] > 4'd0) begin
                                // Both positive: sort by max_prefix descending
                                if (max_prefix[j] < max_prefix[j+1]) begin
                                    should_swap <= 1'b1;
                                end
                            end else if (net[j] <= 4'd0 && net[j+1] <= 4'd0) begin
                                // Both non-positive: sort by -net descending, then max_prefix descending
                                if (net[j] > net[j+1]) begin
                                    should_swap <= 1'b1;
                                end else if (net[j] == net[j+1] && max_prefix[j] < max_prefix[j+1]) begin
                                    should_swap <= 1'b1;
                                end
                            end

                            if (should_swap) begin
                                // Swap indices
                                temp_net <= sorted_indices[j];
                                sorted_indices[j] <= sorted_indices[j+1];
                                sorted_indices[j+1] <= temp_net;
                            end

                            j <= j + 8'd1;
                        end else begin
                            i <= i + 8'd1;
                            j <= 8'd0;
                        end
                    end else begin
                        state <= DP_COMPUTE;
                        mask <= 8'd0;
                        balance <= 4'd0;
                        i <= 8'd0;
                        j <= 8'd0;
                        max_result <= 16'd0;
                    end
                end

                DP_COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Initialize DP for mask=0
                    if (mask == 8'd0 && balance == 4'd0) begin
                        dp[0] <= 16'd0;
                        dp_balance[0] <= 4'd0;
                        mask <= 8'd1;
                        balance <= net[sorted_indices[0]];
                        if (balance >= 4'd0) begin
                            dp[1] <= piece_len[sorted_indices[0]];
                            dp_balance[1] <= balance;
                        end
                        i <= 8'd1;
                        j <= 8'd0;
                    end else if (i < 256) begin
                        // Try to extend with each piece
                        if (j < 8) begin
                            temp_mask <= i;
                            temp_balance <= dp_balance[i];

                            // Check if piece j is not in mask
                            if (!(temp_mask[sorted_indices[j]])) begin
                                temp_net <= net[sorted_indices[j]];
                                temp_max_prefix <= max_prefix[sorted_indices[j]];

                                // Calculate new balance
                                temp_balance <= temp_balance + temp_net;

                                // Check constraints
                                if (temp_balance >= 4'd0 && 
                                    (temp_balance - temp_net) + temp_max_prefix >= 4'd0) begin
                                    temp_length <= dp[i] + piece_len[sorted_indices[j]];

                                    // Update new mask
                                    temp_mask <= temp_mask | (1 << sorted_indices[j]);

                                    // Update DP if better
                                    if (temp_length > dp[temp_mask] || 
                                        (temp_length == dp[temp_mask] && temp_balance > dp_balance[temp_mask])) begin
                                        dp[temp_mask] <= temp_length;
                                        dp_balance[temp_mask] <= temp_balance;
                                    end
                                end
                            end

                            j <= j + 8'd1;
                        end else begin
                            i <= i + 8'd1;
                            j <= 8'd0;

                            // Check if we've processed all masks
                            if (i == 8'd255) begin
                                // Find maximum result with balance 0
                                max_result <= 16'd0;
                                for (k = 0; k < 256; k = k + 1) begin
                                    if (dp_balance[k] == 4'd0 && dp[k] > max_result) begin
                                        max_result <= dp[k];
                                    end
                                end
                                result <= max_result;
                                state <= FINISH;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule