module traffic_light_probability (
    input clk,
    input rst_n,
    input start,
    input [7:0] T_g,
    input [7:0] T_y,
    input [7:0] T_r,
    input [3:0] num_obs,
    input [23:0] obs_0,
    input [23:0] obs_1,
    input [23:0] obs_2,
    input [23:0] obs_3,
    input [23:0] obs_4,
    input [23:0] obs_5,
    input [23:0] obs_6,
    input [23:0] obs_7,
    input [15:0] query_time,
    input [1:0] query_color,
    output reg [15:0] probability,
    output reg done
);

    // State machine states
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] COMPUTE_CYCLE = 4'd1;
    localparam [3:0] PROCESS_OBS = 4'd2;
    localparam [3:0] INTERSECT   = 4'd3;
    localparam [3:0] QUERY       = 4'd4;
    localparam [3:0] RESULT      = 4'd5;

    // Registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [15:0] total_cycle;
    reg [3:0] obs_counter;
    reg [15:0] obs_time_reg;
    reg [1:0] obs_color_reg;
    reg [15:0] query_t_mod;
    reg [15:0] valid_start;
    reg [15:0] valid_end;
    reg [15:0] match_start;
    reg [15:0] match_end;
    reg valid_intersected;
    reg [15:0] temp_start;
    reg [15:0] temp_end;
    reg [15:0] temp_intersect_start;
    reg [15:0] temp_intersect_end;
    reg intersect_found;

    // Helper: modular addition
    function [15:0] mod_add;
        input [15:0] a;
        input [15:0] b;
        input [15:0] mod;
        reg [31:0] sum;
        begin
            sum = a + b;
            if (sum >= mod)
                mod_add = sum - mod;
            else
                mod_add = sum;
        end
    endfunction

    // Helper: modular subtraction
    function [15:0] mod_sub;
        input [15:0] a;
        input [15:0] b;
        input [15:0] mod;
        begin
            if (a >= b)
                mod_sub = a - b;
            else
                mod_sub = mod + a - b;
        end
    endfunction

    // Helper: get start/end of color interval from observation
    task get_interval;
        input [15:0] t_obs;
        input [1:0] color;
        input [15:0] t_g;
        input [15:0] t_y;
        input [15:0] cycle;
        output [15:0] start;
        output [15:0] end_point;
        reg [15:0] t_start;
        reg [15:0] t_end;
        begin
            // t_mod = t_obs % cycle
            t_start = t_obs % cycle;
            
            case (color)
                2'd0: begin // Green
                    t_end = mod_add(t_start, t_g, cycle);
                    start = t_start;
                    end_point = t_end;
                end
                2'd1: begin // Yellow
                    t_start = mod_add(t_start, t_g, cycle);
                    t_end = mod_add(t_start, t_y, cycle);
                    start = t_start;
                    end_point = t_end;
                end
                2'd2: begin // Red
                    t_start = mod_add(mod_add(t_start, t_g, cycle), t_y, cycle);
                    t_end = mod_add(t_start, t_r, cycle);
                    start = t_start;
                    end_point = t_end;
                end
                default: begin
                    start = 16'd0;
                    end_point = 16'd0;
                end
            endcase
        end
    endtask

    // Helper: intersect two intervals on a circle
    task intersect_intervals;
        input [15:0] a_start;
        input [15:0] a_end;
        input [15:0] b_start;
        input [15:0] b_end;
        input [15:0] cycle;
        output [15:0] out_start;
        output [15:0] out_end;
        output found;
        reg [15:0] a_len;
        reg [15:0] b_len;
        reg [15:0] dist_ab;
        reg [15:0] dist_ba;
        reg [15:0] overlap_len;
        begin
            found = 1'b0;
            out_start = 16'd0;
            out_end = 16'd0;
            
            // Handle wrap-around: assume intervals are [start, end) with start < end
            // Check if they overlap
            if (a_start < a_end && b_start < b_end) begin
                // Both don't wrap
                if (a_start < b_end && b_start < a_end) begin
                    // Overlap
                    if (a_start > b_start)
                        out_start = a_start;
                    else
                        out_start = b_start;
                    
                    if (a_end < b_end)
                        out_end = a_end;
                    else
                        out_end = b_end;
                    
                    if (out_end > out_start)
                        found = 1'b1;
                end
            end
            // Simplified: only handle non-wrapping intervals for now
        end
    endtask

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE_CYCLE;
            end
            COMPUTE_CYCLE: begin
                next_state = (num_obs > 4'd0) ? PROCESS_OBS : QUERY;
            end
            PROCESS_OBS: begin
                next_state = INTERSECT;
            end
            INTERSECT: begin
                if (obs_counter + 4'd1 >= num_obs)
                    next_state = QUERY;
                else
                    next_state = PROCESS_OBS;
            end
            QUERY: begin
                next_state = RESULT;
            end
            RESULT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            probability <= 16'd0;
            done <= 1'b0;
            total_cycle <= 16'd0;
            obs_counter <= 4'd0;
            obs_time_reg <= 16'd0;
            obs_color_reg <= 2'd0;
            query_t_mod <= 16'd0;
            valid_start <= 16'd0;
            valid_end <= 16'd0;
            match_start <= 16'd0;
            match_end <= 16'd0;
            valid_intersected <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    obs_counter <= 4'd0;
                    valid_intersected <= 1'b0;
                end
                
                COMPUTE_CYCLE: begin
                    total_cycle <= T_g + T_y + T_r;
                    // Initialize valid interval as full cycle
                    valid_start <= 16'd0;
                    valid_end <= T_g + T_y + T_r;
                    valid_intersected <= 1'b1;
                end
                
                PROCESS_OBS: begin
                    // Extract observation based on obs_counter
                    case (obs_counter)
                        4'd0: begin obs_time_reg <= obs_0[15:0]; obs_color_reg <= obs_0[17:16]; end
                        4'd1: begin obs_time_reg <= obs_1[15:0]; obs_color_reg <= obs_1[17:16]; end
                        4'd2: begin obs_time_reg <= obs_2[15:0]; obs_color_reg <= obs_2[17:16]; end
                        4'd3: begin obs_time_reg <= obs_3[15:0]; obs_color_reg <= obs_3[17:16]; end
                        4'd4: begin obs_time_reg <= obs_4[15:0]; obs_color_reg <= obs_4[17:16]; end
                        4'd5: begin obs_time_reg <= obs_5[15:0]; obs_color_reg <= obs_5[17:16]; end
                        4'd6: begin obs_time_reg <= obs_6[15:0]; obs_color_reg <= obs_6[17:16]; end
                        4'd7: begin obs_time_reg <= obs_7[15:0]; obs_color_reg <= obs_7[17:16]; end
                    endcase
                end
                
                INTERSECT: begin
                    if (valid_intersected) begin
                        // Get interval for this observation
                        get_interval(obs_time_reg, obs_color_reg, T_g, T_y, total_cycle, temp_start, temp_end);
                        
                        // Intersect with current valid interval
                        intersect_intervals(valid_start, valid_end, temp_start, temp_end, total_cycle,
                                          match_start, match_end, intersect_found);
                        
                        if (intersect_found) begin
                            valid_start <= match_start;
                            valid_end <= match_end;
                            valid_intersected <= 1'b1;
                        end else begin
                            valid_intersected <= 1'b0;
                        end
                        
                        obs_counter <= obs_counter + 4'd1;
                    end
                end
                
                QUERY: begin
                    query_t_mod <= query_time % total_cycle;
                end
                
                RESULT: begin
                    if (valid_intersected) begin
                        // Compute probability: fraction of cycle where color matches query
                        // Simplified: compute length of query color in valid interval
                        case (query_color)
                            2'd0: begin // Green
                                probability <= (T_g << 8) / total_cycle;
                            end
                            2'd1: begin // Yellow
                                probability <= (T_y << 8) / total_cycle;
                            end
                            2'd2: begin // Red
                                probability <= (T_r << 8) / total_cycle;
                            end
                            default: probability <= 16'd0;
                        endcase
                    end else begin
                        probability <= 16'd0;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule