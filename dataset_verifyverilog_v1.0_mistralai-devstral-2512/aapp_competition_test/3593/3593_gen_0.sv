module TilingSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] row_data [0:7][0:2],
    input wire [7:0] total_K,
    output reg signed [15:0] max_sum,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS_ROW = 4'd1;
    localparam [3:0] COMPUTE_MAX = 4'd2;
    localparam [3:0] FINISH = 4'd3;

    reg [3:0] state;
    reg [3:0] row_idx;
    reg [2:0] prev_mask;
    reg [2:0] curr_mask;
    reg [7:0] k_idx;
    reg [7:0] added_tiles;
    reg signed [15:0] current_sum;
    reg signed [15:0] temp_sum;
    reg signed [15:0] dp [0:15][0:7];
    reg signed [15:0] new_dp [0:15][0:7];
    reg [2:0] horizontal_config;
    reg [2:0] free_cells;
    reg [2:0] h_tiles;
    reg [2:0] v_tiles;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 4'd0;
            prev_mask <= 3'd0;
            curr_mask <= 3'd0;
            k_idx <= 8'd0;
            added_tiles <= 8'd0;
            current_sum <= 16'd0;
            temp_sum <= 16'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            max_sum <= 16'd0;
            // Initialize dp array
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dp[i][j] <= 16'h8000;
                end
            end
            dp[0][0] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS_ROW;
                        row_idx <= 4'd0;
                        prev_mask <= 3'd0;
                        k_idx <= 8'd0;
                    end
                end

                PROCESS_ROW: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Initialize new_dp
                        integer i, j;
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                new_dp[i][j] <= 16'h8000;
                            end
                        end

                        // Iterate over all prev_mask and k_idx
                        for (prev_mask = 0; prev_mask < 8; prev_mask = prev_mask + 1) begin
                            for (k_idx = 0; k_idx < 16; k_idx = k_idx + 1) begin
                                if (dp[k_idx][prev_mask] != 16'h8000) begin
                                    current_sum <= dp[k_idx][prev_mask];

                                    // Determine free cells (not covered by vertical from prev)
                                    free_cells <= ~prev_mask & 7;

                                    // Try all possible curr_mask (vertical tiles starting at current row)
                                    for (curr_mask = 0; curr_mask < 8; curr_mask = curr_mask + 1) begin
                                        // Check if curr_mask is subset of free_cells
                                        if ((curr_mask & ~free_cells) == 0) begin
                                            // Count vertical tiles
                                            v_tiles <= curr_mask;
                                            added_tiles <= 0;
                                            temp_sum <= current_sum;

                                            // Add vertical tile values
                                            integer col;
                                            for (col = 0; col < 3; col = col + 1) begin
                                                if (curr_mask[col]) begin
                                                    temp_sum <= temp_sum + row_data[row_idx][col];
                                                    added_tiles <= added_tiles + 1;
                                                end
                                            end

                                            // Generate all horizontal tile configurations on remaining free cells
                                            free_cells <= free_cells & ~curr_mask;
                                            for (horizontal_config = 0; horizontal_config < 8; horizontal_config = horizontal_config + 1) begin
                                                if ((horizontal_config & ~free_cells) == 0) begin
                                                    // Check for valid horizontal dominoes
                                                    h_tiles <= 0;
                                                    if ((horizontal_config[0] && horizontal_config[1]) || (!horizontal_config[0] && !horizontal_config[1])) begin
                                                        if (horizontal_config[0] && horizontal_config[1]) begin
                                                            h_tiles <= h_tiles | 3'd3; // bits 0 and 1
                                                        end
                                                    end
                                                    if ((horizontal_config[1] && horizontal_config[2]) || (!horizontal_config[1] && !horizontal_config[2])) begin
                                                        if (horizontal_config[1] && horizontal_config[2]) begin
                                                            h_tiles <= h_tiles | 3'd6; // bits 1 and 2
                                                        end
                                                    end

                                                    // Count horizontal tiles
                                                    integer h_count;
                                                    h_count <= 0;
                                                    if (h_tiles[0] && h_tiles[1]) h_count <= h_count + 1;
                                                    if (h_tiles[1] && h_tiles[2]) h_count <= h_count + 1;

                                                    // Add horizontal tile values
                                                    integer h_sum;
                                                    h_sum <= 0;
                                                    if (h_tiles[0] && h_tiles[1]) begin
                                                        h_sum <= h_sum + row_data[row_idx][0] + row_data[row_idx][1];
                                                    end
                                                    if (h_tiles[1] && h_tiles[2]) begin
                                                        h_sum <= h_sum + row_data[row_idx][1] + row_data[row_idx][2];
                                                    end

                                                    // Update new_dp
                                                    if ((k_idx + added_tiles + h_count) < 16) begin
                                                        if (temp_sum + h_sum > new_dp[k_idx + added_tiles + h_count][curr_mask]) begin
                                                            new_dp[k_idx + added_tiles + h_count][curr_mask] <= temp_sum + h_sum;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        // Copy new_dp to dp
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                dp[i][j] <= new_dp[i][j];
                            end
                        end

                        // Move to next row
                        if (row_idx == 4'd7) begin
                            state <= COMPUTE_MAX;
                        end else begin
                            row_idx <= row_idx + 4'd1;
                        end
                    end
                end

                COMPUTE_MAX: begin
                    max_sum <= 16'h8000;
                    for (k_idx = 0; k_idx < 16; k_idx = k_idx + 1) begin
                        if (k_idx <= total_K) begin
                            for (curr_mask = 0; curr_mask < 8; curr_mask = curr_mask + 1) begin
                                if (dp[k_idx][curr_mask] > max_sum) begin
                                    max_sum <= dp[k_idx][curr_mask];
                                end
                            end
                        end
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule