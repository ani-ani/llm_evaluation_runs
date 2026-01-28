module job_scheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire offers_valid,
    input wire [15:0] offer_time_0,
    input wire [15:0] offer_time_1,
    input wire [15:0] offer_time_2,
    input wire [15:0] offer_time_3,
    input wire [15:0] offer_time_4,
    input wire [15:0] offer_time_5,
    input wire [15:0] offer_time_6,
    input wire [15:0] offer_time_7,
    input wire [15:0] offer_time_8,
    input wire [15:0] offer_time_9,
    input wire [15:0] offer_time_10,
    input wire [15:0] offer_time_11,
    input wire [15:0] offer_time_12,
    input wire [15:0] offer_time_13,
    input wire [15:0] offer_time_14,
    input wire [15:0] offer_time_15,
    input wire [3:0] N,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE_DP = 3'd2;
    localparam [2:0] SEARCH_J = 3'd3;
    localparam [2:0] UPDATE_DP = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;

    // DP array and current index
    reg [15:0] dp [0:15];
    reg [3:0] i_reg, j_reg;

    // Current offer time and duration/reward selections
    reg [15:0] current_time;
    reg [15:0] max_reward;
    reg [15:0] temp_reward;

    // Duration and reward constants
    localparam [15:0] DURATION_SMALL = 16'd20;
    localparam [15:0] DURATION_MEDIUM = 16'd30;
    localparam [15:0] DURATION_LARGE = 16'd40;
    localparam [15:0] REWARD_SMALL = 16'd1;
    localparam [15:0] REWARD_MEDIUM = 16'd3;
    localparam [15:0] REWARD_LARGE = 16'd4;

    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            current_time <= 16'd0;
            max_reward <= 16'd0;
            temp_reward <= 16'd0;
            // Initialize dp array
            dp[0] <= 16'd0;
            dp[1] <= 16'd0;
            dp[2] <= 16'd0;
            dp[3] <= 16'd0;
            dp[4] <= 16'd0;
            dp[5] <= 16'd0;
            dp[6] <= 16'd0;
            dp[7] <= 16'd0;
            dp[8] <= 16'd0;
            dp[9] <= 16'd0;
            dp[10] <= 16'd0;
            dp[11] <= 16'd0;
            dp[12] <= 16'd0;
            dp[13] <= 16'd0;
            dp[14] <= 16'd0;
            dp[15] <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && offers_valid) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize dp[0] based on first offer
                    case (N)
                        4'd1: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd2: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd3: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd4: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd5: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd6: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd7: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd8: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd9: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd10: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd11: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd12: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd13: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd14: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd15: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        4'd16: begin
                            dp[0] <= REWARD_LARGE;
                            i_reg <= 4'd1;
                        end
                        default: begin
                            dp[0] <= 16'd0;
                            i_reg <= 4'd1;
                        end
                    endcase
                    next_state <= COMPUTE_DP;
                end

                COMPUTE_DP: begin
                    // Load current offer time
                    case (i_reg)
                        4'd0: current_time <= offer_time_0;
                        4'd1: current_time <= offer_time_1;
                        4'd2: current_time <= offer_time_2;
                        4'd3: current_time <= offer_time_3;
                        4'd4: current_time <= offer_time_4;
                        4'd5: current_time <= offer_time_5;
                        4'd6: current_time <= offer_time_6;
                        4'd7: current_time <= offer_time_7;
                        4'd8: current_time <= offer_time_8;
                        4'd9: current_time <= offer_time_9;
                        4'd10: current_time <= offer_time_10;
                        4'd11: current_time <= offer_time_11;
                        4'd12: current_time <= offer_time_12;
                        4'd13: current_time <= offer_time_13;
                        4'd14: current_time <= offer_time_14;
                        4'd15: current_time <= offer_time_15;
                        default: current_time <= 16'd0;
                    endcase

                    // Initialize max_reward with dp[i-1]
                    if (i_reg > 4'd0) begin
                        max_reward <= dp[i_reg - 4'd1];
                    end else begin
                        max_reward <= 16'd0;
                    end

                    // Initialize j_reg for search
                    j_reg <= i_reg - 4'd1;
                    next_state <= SEARCH_J;
                end

                SEARCH_J: begin
                    // Check if j_reg is valid
                    if (j_reg >= 4'd0) begin
                        // Load offer time for j
                        reg [15:0] j_time;
                        case (j_reg)
                            4'd0: j_time = offer_time_0;
                            4'd1: j_time = offer_time_1;
                            4'd2: j_time = offer_time_2;
                            4'd3: j_time = offer_time_3;
                            4'd4: j_time = offer_time_4;
                            4'd5: j_time = offer_time_5;
                            4'd6: j_time = offer_time_6;
                            4'd7: j_time = offer_time_7;
                            4'd8: j_time = offer_time_8;
                            4'd9: j_time = offer_time_9;
                            4'd10: j_time = offer_time_10;
                            4'd11: j_time = offer_time_11;
                            4'd12: j_time = offer_time_12;
                            4'd13: j_time = offer_time_13;
                            4'd14: j_time = offer_time_14;
                            4'd15: j_time = offer_time_15;
                            default: j_time = 16'd0;
                        endcase

                        // Check small duration
                        if (j_time + DURATION_SMALL <= current_time) begin
                            temp_reward <= dp[j_reg] + REWARD_SMALL;
                            if (temp_reward > max_reward) begin
                                max_reward <= temp_reward;
                            end
                        end

                        // Check medium duration
                        if (j_time + DURATION_MEDIUM <= current_time) begin
                            temp_reward <= dp[j_reg] + REWARD_MEDIUM;
                            if (temp_reward > max_reward) begin
                                max_reward <= temp_reward;
                            end
                        end

                        // Check large duration
                        if (j_time + DURATION_LARGE <= current_time) begin
                            temp_reward <= dp[j_reg] + REWARD_LARGE;
                            if (temp_reward > max_reward) begin
                                max_reward <= temp_reward;
                            end
                        end

                        // Decrement j_reg
                        j_reg <= j_reg - 4'd1;
                    end else begin
                        // Move to update state
                        next_state <= UPDATE_DP;
                    end
                end

                UPDATE_DP: begin
                    // Store max_reward in dp[i_reg]
                    case (i_reg)
                        4'd0: dp[0] <= max_reward;
                        4'd1: dp[1] <= max_reward;
                        4'd2: dp[2] <= max_reward;
                        4'd3: dp[3] <= max_reward;
                        4'd4: dp[4] <= max_reward;
                        4'd5: dp[5] <= max_reward;
                        4'd6: dp[6] <= max_reward;
                        4'd7: dp[7] <= max_reward;
                        4'd8: dp[8] <= max_reward;
                        4'd9: dp[9] <= max_reward;
                        4'd10: dp[10] <= max_reward;
                        4'd11: dp[11] <= max_reward;
                        4'd12: dp[12] <= max_reward;
                        4'd13: dp[13] <= max_reward;
                        4'd14: dp[14] <= max_reward;
                        4'd15: dp[15] <= max_reward;
                        default: ;
                    endcase

                    // Increment i_reg
                    if (i_reg < N - 4'd1) begin
                        i_reg <= i_reg + 4'd1;
                        next_state <= COMPUTE_DP;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    // Output result
                    case (N - 4'd1)
                        4'd0: result <= dp[0];
                        4'd1: result <= dp[1];
                        4'd2: result <= dp[2];
                        4'd3: result <= dp[3];
                        4'd4: result <= dp[4];
                        4'd5: result <= dp[5];
                        4'd6: result <= dp[6];
                        4'd7: result <= dp[7];
                        4'd8: result <= dp[8];
                        4'd9: result <= dp[9];
                        4'd10: result <= dp[10];
                        4'd11: result <= dp[11];
                        4'd12: result <= dp[12];
                        4'd13: result <= dp[13];
                        4'd14: result <= dp[14];
                        4'd15: result <= dp[15];
                        default: result <= 16'd0;
                    endcase

                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety check for cycle count
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule