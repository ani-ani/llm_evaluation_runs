module scavenger_hunt_dp(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_tasks,
    input [7:0] T_limit,
    input [6:0] p_i [0:15],
    input [7:0] t_i [0:15],
    input [7:0] d_i [0:15],
    input [7:0] travel [0:17][0:17],
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
    localparam [2:0] FINISH = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] mask_reg;
    reg [3:0] i_reg, j_reg;
    reg [7:0] travel_time;
    reg [7:0] arrival_time;
    reg [7:0] task_time;
    reg [7:0] deadline;
    reg [11:0] new_points;
    reg [15:0] task_mask_temp;
    reg [15:0] best_mask;
    reg [11:0] best_points;
    reg [7:0] best_time;
    reg [3:0] current_loc;
    reg [7:0] current_time;
    reg [7:0] current_points;
    reg [15:0] current_mask;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Combined travel time lookup
    wire [7:0] travel_time_out;
    assign travel_time_out = travel[current_loc][j_reg];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_points <= 12'd0;
            task_mask <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            mask_reg <= 16'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            best_mask <= 16'd0;
            best_points <= 12'd0;
            best_time <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize best to invalid
                    best_points <= 12'd0;
                    best_mask <= 16'd0;
                    best_time <= 8'd255;
                    mask_reg <= 16'd0;
                    i_reg <= 4'd0;
                    j_reg <= 4'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Process states up to cycle limit
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Simple iterative DP: check paths from start to tasks
                    if (cycle_count < MAX_CYCLES) begin
                        if (i_reg < n_tasks) begin
                            // Try to reach task i from start
                            current_loc <= 4'd16;
                            current_mask <= 16'd0;
                            
                            // Calculate travel time
                            if (travel[16][i_reg] + t_i[i_reg] <= T_limit) begin
                                // Check deadline
                                if (d_i[i_reg] == 8'd255 || travel[16][i_reg] + t_i[i_reg] <= d_i[i_reg]) begin
                                    arrival_time <= travel[16][i_reg] + t_i[i_reg];
                                    task_time <= t_i[i_reg];
                                    deadline <= d_i[i_reg];
                                    travel_time <= travel[16][i_reg];
                                    
                                    // Check if this is better than best
                                    if (p_i[i_reg] > best_points || (p_i[i_reg] == best_points && i_reg < n_tasks)) begin
                                        best_points <= p_i[i_reg];
                                        best_mask <= (16'd1 << i_reg);
                                        best_time <= arrival_time;
                                    end
                                end
                            end
                            
                            // Try to extend to other tasks
                            j_reg <= j_reg + 4'd1;
                            if (j_reg >= n_tasks) begin
                                j_reg <= 4'd0;
                                i_reg <= i_reg + 4'd1;
                            end
                        end else begin
                            state <= FINAL;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINAL: begin
                    // Try to extend best solution to other tasks
                    if (i_reg < n_tasks) begin
                        // Check if task not already in best_mask
                        if ((best_mask & (16'd1 << i_reg)) == 16'd0) begin
                            current_loc <= j_reg;
                            current_mask <= best_mask;
                            current_points <= best_points;
                            current_time <= best_time;
                            
                            // Try transition
                            if (best_time + travel[j_reg][i_reg] + t_i[i_reg] <= T_limit) begin
                                if (d_i[i_reg] == 8'd255 || best_time + travel[j_reg][i_reg] + t_i[i_reg] <= d_i[i_reg]) begin
                                    new_points <= best_points + p_i[i_reg];
                                    task_mask_temp <= best_mask | (16'd1 << i_reg);
                                    
                                    // Update best if better
                                    if (new_points > best_points) begin
                                        best_points <= new_points;
                                        best_mask <= task_mask_temp;
                                        best_time <= best_time + travel[j_reg][i_reg] + t_i[i_reg];
                                    end
                                end
                            end
                        end
                        i_reg <= i_reg + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Check if we can reach end node
                    if (best_points > 4'd0 && best_time <= T_limit) begin
                        max_points <= best_points;
                        task_mask <= best_mask;
                        valid <= 1'b1;
                    end else begin
                        max_points <= 12'd0;
                        task_mask <= 16'd0;
                        valid <= 1'b1; // Timeout or no solution
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule