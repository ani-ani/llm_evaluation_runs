module scavenger_hunt_dp(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_tasks,
    input wire [7:0] T_limit,
    input wire [6:0] p_i [0:15],
    input wire [7:0] t_i [0:15],
    input wire [7:0] d_i [0:15],
    input wire [143:0] travel [0:17],
    output reg [11:0] max_points,
    output reg [15:0] task_mask,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINAL = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // DP state storage (using registers for synthesis)
    reg [7:0] dp_time [0:65535][0:17];
    reg [11:0] dp_points [0:65535][0:17];
    reg [15:0] dp_prev_mask [0:65535][0:17];
    reg [4:0] dp_prev_loc [0:65535][0:17];

    // Current state tracking
    reg [2:0] state;
    reg [15:0] current_mask;
    reg [4:0] current_loc;
    reg [15:0] best_mask;
    reg [11:0] best_points;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd100000;

    // Travel time extraction helper
    function [7:0] get_travel_time;
        input [4:0] from;
        input [4:0] to;
        begin
            get_travel_time = travel[from][(to * 8) +: 8];
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_mask <= 16'd0;
            current_loc <= 5'd0;
            best_mask <= 16'd0;
            best_points <= 12'd0;
            cycle_count <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            max_points <= 12'd0;
            task_mask <= 16'd0;

            // Initialize DP arrays
            integer i, j;
            for (i = 0; i < 65536; i = i + 1) begin
                for (j = 0; j < 18; j = j + 1) begin
                    dp_time[i][j] <= 8'd0;
                    dp_points[i][j] <= 12'd0;
                    dp_prev_mask[i][j] <= 16'd0;
                    dp_prev_loc[i][j] <= 5'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 16'd0;
                    end
                end

                INIT: begin
                    // Initialize from start location (16) to each task
                    integer j;
                    for (j = 0; j < n_tasks; j = j + 1) begin
                        dp_time[1 << j][j] <= get_travel_time(5'd16, 5'd0 + j) + t_i[j];
                        dp_points[1 << j][j] <= p_i[j];
                        dp_prev_mask[1 << j][j] <= 16'd0;
                        dp_prev_loc[1 << j][j] <= 5'd16;
                    end
                    state <= COMPUTE;
                    current_mask <= 16'd1;
                    current_loc <= 5'd0;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Check if we've processed all masks
                    if (current_mask == (1 << n_tasks) - 1) begin
                        state <= FINAL;
                    end else begin
                        // Process current state
                        integer i, j;
                        reg [7:0] current_time;
                        reg [11:0] current_points;
                        
                        // Find current location with valid state
                        for (i = 0; i < n_tasks; i = i + 1) begin
                            if (current_mask[i]) begin
                                current_loc = 5'd0 + i;
                                current_time = dp_time[current_mask][i];
                                current_points = dp_points[current_mask][i];
                            end
                        end

                        // Try transitions to unvisited tasks
                        for (j = 0; j < n_tasks; j = j + 1) begin
                            if (!current_mask[j]) begin
                                reg [7:0] travel_time;
                                reg [7:0] new_time;
                                reg [11:0] new_points;
                                reg [15:0] new_mask;
                                
                                travel_time = get_travel_time(current_loc, 5'd0 + j);
                                new_time = current_time + travel_time + t_i[j];
                                new_points = current_points + p_i[j];
                                new_mask = current_mask | (1 << j);

                                // Check constraints
                                if ((d_i[j] != 8'd255 && new_time <= d_i[j]) || d_i[j] == 8'd255) begin
                                    if (new_time <= T_limit) begin
                                        // Update DP state if better
                                        if (new_points > dp_points[new_mask][j] ||
                                            (new_points == dp_points[new_mask][j] && new_mask < dp_prev_mask[new_mask][j])) begin
                                            dp_time[new_mask][j] <= new_time;
                                            dp_points[new_mask][j] <= new_points;
                                            dp_prev_mask[new_mask][j] <= current_mask;
                                            dp_prev_loc[new_mask][j] <= current_loc;
                                        end
                                    end
                                end
                            end
                        end

                        // Move to next mask
                        current_mask <= current_mask + 16'd1;
                    end
                    
                    // Safety check for cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINAL;
                    end
                end

                FINAL: begin
                    // Find best path to end location
                    integer i;
                    reg [7:0] final_time;
                    reg [11:0] final_points;
                    reg [15:0] final_mask;
                    
                    best_points <= 12'd0;
                    best_mask <= 16'd0;
                    
                    for (i = 0; i < n_tasks; i = i + 1) begin
                        integer mask;
                        for (mask = 0; mask < 65536; mask = mask + 1) begin
                            if (mask[i] && dp_points[mask][i] > 0) begin
                                final_time = dp_time[mask][i] + get_travel_time(5'd0 + i, 5'd17);
                                final_points = dp_points[mask][i];
                                final_mask = mask;
                                
                                if (final_time <= T_limit) begin
                                    if (final_points > best_points ||
                                        (final_points == best_points && final_mask < best_mask)) begin
                                        best_points <= final_points;
                                        best_mask <= final_mask;
                                    end
                                end
                            end
                        end
                    end
                    
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= (best_points > 0) ? 1'b1 : 1'b1; // valid=1 even if no solution
                    max_points <= best_points;
                    task_mask <= best_mask;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule