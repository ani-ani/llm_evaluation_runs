module BaricaFrog(
    input clk,
    input rst_n,
    input start,
    input [15:0] plant_x [0:15],
    input [15:0] plant_y [0:15],
    input [9:0] plant_f [0:15],
    input [4:0] num_plants,
    input [9:0] jump_cost,
    output reg [15:0] result_energy,
    output reg [4:0] path_count,
    output reg [3:0] path_idx [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_UPDATE = 3'd3;
    localparam [2:0] PATH_RECON = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // DP arrays
    reg [15:0] energy_dp [0:15];
    reg [3:0] prev_dp [0:15];
    reg valid_dp [0:15];

    // Sorting variables
    reg [15:0] sorted_x [0:15];
    reg [15:0] sorted_y [0:15];
    reg [9:0] sorted_f [0:15];
    reg [3:0] sorted_idx [0:15];
    reg [4:0] sort_i, sort_j;
    reg [15:0] temp_x, temp_y;
    reg [9:0] temp_f;
    reg [3:0] temp_idx;

    // DP update variables
    reg [4:0] dp_i, dp_j;
    reg [15:0] current_energy;
    reg can_jump;

    // Path reconstruction variables
    reg [4:0] path_i;
    reg [3:0] current_idx;

    // Initialize all registers
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_energy <= 16'd0;
            path_count <= 5'd0;
            for (k = 0; k < 16; k = k + 1) begin
                path_idx[k] <= 4'd0;
                energy_dp[k] <= 16'd0;
                prev_dp[k] <= 4'd0;
                valid_dp[k] <= 1'b0;
                sorted_x[k] <= 16'd0;
                sorted_y[k] <= 16'd0;
                sorted_f[k] <= 10'd0;
                sorted_idx[k] <= 4'd0;
            end
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            dp_i <= 5'd0;
            dp_j <= 5'd0;
            path_i <= 5'd0;
            current_idx <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SORT;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count < 8'd1) begin
                        // Initialize sorted arrays
                        for (k = 0; k < 16; k = k + 1) begin
                            sorted_x[k] <= plant_x[k];
                            sorted_y[k] <= plant_y[k];
                            sorted_f[k] <= plant_f[k];
                            sorted_idx[k] <= k;
                        end
                        sort_i <= 5'd0;
                        sort_j <= 5'd0;
                    end
                    // Bubble sort by x then y
                    if (sort_i < num_plants - 1) begin
                        if (sort_j < num_plants - sort_i - 1) begin
                            if (sorted_x[sort_j] > sorted_x[sort_j + 1] ||
                                (sorted_x[sort_j] == sorted_x[sort_j + 1] && sorted_y[sort_j] > sorted_y[sort_j + 1])) begin
                                // Swap
                                temp_x <= sorted_x[sort_j];
                                temp_y <= sorted_y[sort_j];
                                temp_f <= sorted_f[sort_j];
                                temp_idx <= sorted_idx[sort_j];
                                sorted_x[sort_j] <= sorted_x[sort_j + 1];
                                sorted_y[sort_j] <= sorted_y[sort_j + 1];
                                sorted_f[sort_j] <= sorted_f[sort_j + 1];
                                sorted_idx[sort_j] <= sorted_idx[sort_j + 1];
                                sorted_x[sort_j + 1] <= temp_x;
                                sorted_y[sort_j + 1] <= temp_y;
                                sorted_f[sort_j + 1] <= temp_f;
                                sorted_idx[sort_j + 1] <= temp_idx;
                            end
                            sort_j <= sort_j + 5'd1;
                        end else begin
                            sort_j <= 5'd0;
                            sort_i <= sort_i + 5'd1;
                        end
                    end else begin
                        next_state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize DP for starting plant (index 0 in sorted array)
                    energy_dp[0] <= sorted_f[0];
                    valid_dp[0] <= 1'b1;
                    prev_dp[0] <= 4'd0;
                    dp_i <= 5'd1;
                    dp_j <= 5'd0;
                    next_state <= DP_UPDATE;
                end

                DP_UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (dp_i < num_plants) begin
                        if (dp_j < dp_i) begin
                            // Check if dp_j can jump to dp_i
                            can_jump = 1'b0;
                            if (valid_dp[dp_j]) begin
                                if ((sorted_x[dp_i] > sorted_x[dp_j] && sorted_y[dp_i] == sorted_y[dp_j]) ||
                                    (sorted_y[dp_i] > sorted_y[dp_j] && sorted_x[dp_i] == sorted_x[dp_j])) begin
                                    if (energy_dp[dp_j] >= jump_cost) begin
                                        can_jump = 1'b1;
                                    end
                                end
                            end

                            if (can_jump) begin
                                current_energy = energy_dp[dp_j] - jump_cost + sorted_f[dp_i];
                                if (!valid_dp[dp_i] || current_energy > energy_dp[dp_i]) begin
                                    energy_dp[dp_i] <= current_energy;
                                    prev_dp[dp_i] <= sorted_idx[dp_j];
                                    valid_dp[dp_i] <= 1'b1;
                                end
                            end
                            dp_j <= dp_j + 5'd1;
                        end else begin
                            dp_j <= 5'd0;
                            dp_i <= dp_i + 5'd1;
                        end
                    end else begin
                        next_state <= PATH_RECON;
                        path_i <= 5'd0;
                        current_idx <= sorted_idx[num_plants - 1];
                    end
                end

                PATH_RECON: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (path_i < num_plants) begin
                        path_idx[path_i] <= current_idx;
                        if (current_idx != 4'd0) begin
                            current_idx <= prev_dp[current_idx];
                        end
                        path_i <= path_i + 5'd1;
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_energy <= energy_dp[num_plants - 1];
                    path_count <= num_plants;
                    next_state <= DONE_STATE;
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