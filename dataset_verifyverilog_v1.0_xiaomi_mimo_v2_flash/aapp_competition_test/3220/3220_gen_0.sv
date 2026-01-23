module circle_dance(
    input clk,
    input rst_n,
    input start,
    input [7:0] p_0,
    input [7:0] p_1,
    input [7:0] p_2,
    input [7:0] p_3,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg done,
    output reg valid
);

    localparam [7:0] ASCII_L = 8'd76;
    localparam [7:0] ASCII_R = 8'd82;
    localparam [2:0] NUM_WIZARDS = 3'd4;
    localparam [3:0] MAX_COMBINATIONS = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd256;

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] combo_counter;
    reg [7:0] cycle_counter;
    reg [3:0] current_directions;
    reg [3:0] positions [0:3];
    reg collision_detected;
    reg [2:0] i_idx;
    reg [2:0] j_idx;
    reg [7:0] temp_p_i;
    reg [2:0] pos_calc;
    reg [7:0] calc_result;
    reg found_solution;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            combo_counter <= 4'd0;
            cycle_counter <= 8'd0;
            current_directions <= 4'd0;
            positions[0] <= 3'd0;
            positions[1] <= 3'd0;
            positions[2] <= 3'd0;
            positions[3] <= 3'd0;
            collision_detected <= 1'b0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            temp_p_i <= 8'd0;
            pos_calc <= 3'd0;
            calc_result <= 8'd0;
            found_solution <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    combo_counter <= 4'd0;
                    cycle_counter <= 8'd0;
                    found_solution <= 1'b0;
                    i_idx <= 3'd0;
                    if (start) begin
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    cycle_counter <= cycle_counter + 8'd1;

                    if (combo_counter < MAX_COMBINATIONS && !found_solution && cycle_counter < MAX_CYCLES) begin
                        // Calculate positions for current combination
                        case (i_idx)
                            3'd0: begin
                                temp_p_i <= p_0;
                                pos_calc <= (current_directions[0] == 1'b0) ? 
                                    (3'd0 + p_0[2:0]) % 3'd4 : 
                                    (3'd0 + 3'd4 - p_0[2:0]) % 3'd4;
                            end
                            3'd1: begin
                                temp_p_i <= p_1;
                                pos_calc <= (current_directions[1] == 1'b0) ? 
                                    (3'd1 + p_1[2:0]) % 3'd4 : 
                                    (3'd1 + 3'd4 - p_1[2:0]) % 3'd4;
                            end
                            3'd2: begin
                                temp_p_i <= p_2;
                                pos_calc <= (current_directions[2] == 1'b0) ? 
                                    (3'd2 + p_2[2:0]) % 3'd4 : 
                                    (3'd2 + 3'd4 - p_2[2:0]) % 3'd4;
                            end
                            3'd3: begin
                                temp_p_i <= p_3;
                                pos_calc <= (current_directions[3] == 1'b0) ? 
                                    (3'd3 + p_3[2:0]) % 3'd4 : 
                                    (3'd3 + 3'd4 - p_3[2:0]) % 3'd4;
                            end
                            default: begin
                                temp_p_i <= 8'd0;
                                pos_calc <= 3'd0;
                            end
                        endcase

                        positions[i_idx] <= pos_calc;
                        i_idx <= i_idx + 3'd1;

                        if (i_idx == 3'd3) begin
                            // Finished calculating positions, now check for collision
                            i_idx <= 3'd0;
                            collision_detected <= 1'b0;
                            j_idx <= 3'd1;
                        end
                    end else if (i_idx == 3'd0 && j_idx > 3'd0) begin
                        // Collision check in progress
                        if (!collision_detected) begin
                            if (positions[i_idx] == positions[j_idx]) begin
                                collision_detected <= 1'b1;
                            end
                            j_idx <= j_idx + 3'd1;
                            if (j_idx == 3'd3) begin
                                i_idx <= i_idx + 3'd1;
                                if (i_idx < 3'd3) begin
                                    j_idx <= i_idx + 3'd2;
                                end else begin
                                    j_idx <= 3'd0;
                                end
                            end
                        end
                    end else if (i_idx < 3'd3 && j_idx > 3'd0) begin
                        if (!collision_detected) begin
                            if (positions[i_idx] == positions[j_idx]) begin
                                collision_detected <= 1'b1;
                            end
                            j_idx <= j_idx + 3'd1;
                            if (j_idx == 3'd3) begin
                                i_idx <= i_idx + 3'd1;
                                if (i_idx < 3'd2) begin
                                    j_idx <= i_idx + 3'd2;
                                end else begin
                                    j_idx <= 3'd0;
                                end
                            end
                        end
                    end else if (i_idx >= 3'd3) begin
                        // Collision check complete
                        if (!collision_detected) begin
                            // Valid solution found
                            found_solution <= 1'b1;
                            result_0 <= (current_directions[0] == 1'b0) ? ASCII_L : ASCII_R;
                            result_1 <= (current_directions[1] == 1'b0) ? ASCII_L : ASCII_R;
                            result_2 <= (current_directions[2] == 1'b0) ? ASCII_L : ASCII_R;
                            result_3 <= (current_directions[3] == 1'b0) ? ASCII_L : ASCII_R;
                            state <= FINISH;
                        end else begin
                            // Try next combination
                            combo_counter <= combo_counter + 4'd1;
                            current_directions <= current_directions + 4'd1;
                            i_idx <= 3'd0;
                            j_idx <= 3'd0;
                        end
                    end

                    if (combo_counter >= MAX_COMBINATIONS && !found_solution) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= found_solution;
                    if (found_solution == 1'b0) begin
                        result_0 <= 8'd0;
                        result_1 <= 8'd0;
                        result_2 <= 8'd0;
                        result_3 <= 8'd0;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule