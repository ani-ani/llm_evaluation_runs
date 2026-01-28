module WeightedIntervalScheduling (
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
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_OFFERS  = 3'd1;
    localparam [2:0] INIT_DP      = 3'd2;
    localparam [2:0] COMPUTE_I    = 3'd3;
    localparam [2:0] SEARCH_J     = 3'd4;
    localparam [2:0] UPDATE_DP    = 3'd5;
    localparam [2:0] FINISH       = 3'd6;

    // Durations and Rewards
    localparam [15:0] DUR_SMALL  = 16'd20;
    localparam [15:0] DUR_MED    = 16'd30;
    localparam [15:0] DUR_LARGE  = 16'd40;
    localparam [15:0] REW_SMALL  = 16'd1;
    localparam [15:0] REW_MED    = 16'd3;
    localparam [15:0] REW_LARGE  = 16'd4;

    // Internal Registers
    reg [2:0] state;
    reg [3:0] i; // Current offer index (0 to N-1)
    reg [3:0] j; // Search index (0 to i-1)
    reg [1:0] option; // 0: skip, 1: small, 2: med, 3: large
    reg [3:0] N_reg; // Store N
    
    // DP Array and Time Array (16 elements)
    reg [15:0] dp [0:15];
    reg [15:0] times [0:15];
    
    // Temporary calculations
    reg [15:0] current_time;
    reg [15:0] candidate_reward;
    reg [15:0] max_reward;
    reg [15:0] search_end_time;
    
    // Cycle counter for safety
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd4000;
    
    // Wire for time comparison
    wire is_compatible;
    assign is_compatible = (times[j] <= search_end_time);

    integer idx; // For loop initialization

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            option <= 2'd0;
            N_reg <= 4'd0;
            cycle_count <= 12'd0;
            current_time <= 16'd0;
            candidate_reward <= 16'd0;
            max_reward <= 16'd0;
            search_end_time <= 16'd0;
            // Initialize arrays
            for (idx = 0; idx < 16; idx = idx + 1) begin
                dp[idx] <= 16'd0;
                times[idx] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 12'd0;
                    if (start && offers_valid) begin
                        N_reg <= N;
                        state <= LOAD_OFFERS;
                        i <= 4'd0; // Start loading at index 0
                    end
                end

                LOAD_OFFERS: begin
                    // Load inputs into times array
                    case (i)
                        4'd0:  times[0]  <= offer_time_0;
                        4'd1:  times[1]  <= offer_time_1;
                        4'd2:  times[2]  <= offer_time_2;
                        4'd3:  times[3]  <= offer_time_3;
                        4'd4:  times[4]  <= offer_time_4;
                        4'd5:  times[5]  <= offer_time_5;
                        4'd6:  times[6]  <= offer_time_6;
                        4'd7:  times[7]  <= offer_time_7;
                        4'd8:  times[8]  <= offer_time_8;
                        4'd9:  times[9]  <= offer_time_9;
                        4'd10: times[10] <= offer_time_10;
                        4'd11: times[11] <= offer_time_11;
                        4'd12: times[12] <= offer_time_12;
                        4'd13: times[13] <= offer_time_13;
                        4'd14: times[14] <= offer_time_14;
                        4'd15: times[15] <= offer_time_15;
                    endcase

                    if (i == N_reg - 1) begin
                        i <= 4'd0;
                        state <= INIT_DP;
                    end else begin
                        i <= i + 4'd1;
                    end
                end

                INIT_DP: begin
                    // Initialize DP array to 0
                    if (i < 16) begin
                        dp[i] <= 16'd0;
                        if (i == 4'd15) begin
                            i <= 4'd0; // First offer index
                            state <= COMPUTE_I;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        state <= COMPUTE_I;
                    end
                end

                COMPUTE_I: begin
                    // Reset max reward for current offer
                    max_reward <= dp[i - 1]; // Default: skip current
                    option <= 2'd0; // 0: skip (already handled by max_reward init)
                    current_time <= times[i];
                    state <= SEARCH_J;
                    // Start search from i-1 down to 0
                    j <= (i == 0) ? 0 : i - 1;
                end

                SEARCH_J: begin
                    // Check compatibility for current option
                    if (i == 0) begin
                        // Base case: dp[0] = max(0, rewards if compatible with t=-inf)
                        // Since no previous jobs, compatible if end_time <= times[0]
                        // Only need to check non-negative start times (implied)
                        // Actually, for i=0, we just take max of skip (0) and takes
                        state <= UPDATE_DP;
                    end else if (j > 0 || (j == 0 && option != 0)) begin // j loop logic
                        // Calculate search end time based on option
                        case (option)
                            2'd1: search_end_time <= current_time - DUR_SMALL;
                            2'd2: search_end_time <= current_time - DUR_MED;
                            2'd3: search_end_time <= current_time - DUR_LARGE;
                            default: search_end_time <= current_time; // Should not happen for j search
                        endcase
                        
                        // Logic moved to next cycle for comparison or j decrement
                        if (is_compatible) begin
                            // Found compatible job, calculate reward
                            candidate_reward <= dp[j] + 
                                (option == 2'd1 ? REW_SMALL : 
                                 option == 2'd2 ? REW_MED : REW_LARGE);
                            state <= UPDATE_DP;
                        end else begin
                            // Not compatible, check next
                            if (j == 0) begin
                                // No compatible job found for this option
                                // Move to next option or finish
                                if (option == 2'd3) begin
                                    state <= UPDATE_DP;
                                end else begin
                                    option <= option + 2'd1;
                                    j <= (i == 0) ? 0 : i - 1; // Reset j for next option
                                end
                            end else begin
                                j <= j - 4'd1;
                            end
                        end
                    end else begin
                        // j reached 0 and no match found, or i=0 case logic
                        // Move to next option or finish
                        if (option == 2'd3) begin
                            state <= UPDATE_DP;
                        end else begin
                            option <= option + 2'd1;
                            if (i > 0) j <= i - 1;
                            else j <= 0;
                        end
                    end
                    
                    cycle_count <= cycle_count + 12'd1;
                end

                UPDATE_DP: begin
                    // Update dp[i] with max of (skip, candidate)
                    if (option != 0) begin // option 0 is skip (already in max_reward)
                        if (candidate_reward > max_reward)
                            max_reward <= candidate_reward;
                    end
                    
                    // Move to next option if available
                    if (option < 2'd3) begin
                        option <= option + 2'd1;
                        j <= (i == 0) ? 0 : i - 1;
                        state <= SEARCH_J;
                    end else begin
                        // All options processed
                        dp[i] <= max_reward;
                        
                        if (i == N_reg - 1) begin
                            result <= max_reward;
                            state <= FINISH;
                        end else begin
                            i <= i + 4'd1;
                            state <= COMPUTE_I;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= IDLE;
                done <= 1'b1;
                result <= 16'd0;
            end
        end
    end
endmodule