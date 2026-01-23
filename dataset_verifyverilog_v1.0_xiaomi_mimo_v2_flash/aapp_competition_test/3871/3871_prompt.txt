module profit_maximizer(
    input clk, rst_n, start,
    input [2:0] num_candidates,
    input [3:0] candidate_level0, candidate_level1, candidate_level2, candidate_level3,
    input [3:0] candidate_level4, candidate_level5, candidate_level6, candidate_level7,
    input signed [15:0] candidate_cost0, candidate_cost1, candidate_cost2, candidate_cost3,
    input signed [15:0] candidate_cost4, candidate_cost5, candidate_cost6, candidate_cost7,
    input signed [15:0] profit0, profit1, profit2, profit3, profit4, profit5, profit6, profit7,
    input signed [15:0] profit8, profit9, profit10, profit11, profit12, profit13, profit14, profit15,
    output reg signed [31:0] max_profit,
    output reg done
);

    // Parameters
    parameter MAX_LEVEL = 16; // levels 0-15
    parameter MAX_COUNT = 8;  // counts 0-8
    parameter NUM_STATES = 9;
    
    // State encoding
    localparam IDLE = 0;
    localparam INIT = 1;
    localparam PROCESS_CANDIDATE = 2;
    localparam UPDATE_STATE = 3;
    localparam PROPAGATE = 4;
    localparam NEXT_COUNT = 5;
    localparam NEXT_CANDIDATE = 6;
    localparam FINAL_SCAN = 7;
    localparam DONE_STATE = 8;

    // DP table: [level][count]
    reg signed [31:0] dp [0:15][0:8];
    
    // Registers for state machine
    reg [3:0] state, next_state;
    reg [3:0] level_counter, count_counter, candidate_index;
    reg [3:0] current_level, current_count;
    reg signed [31:0] current_value, next_value, max_temp;
    
    // Intermediate signals
    wire signed [31:0] profit_val [0:15];
    wire signed [15:0] cost_val [0:7];
    wire [3:0] level_val [0:7];
    
    // Assign inputs to arrays for easier access
    assign level_val[0] = candidate_level0;
    assign level_val[1] = candidate_level1;
    assign level_val[2] = candidate_level2;
    assign level_val[3] = candidate_level3;
    assign level_val[4] = candidate_level4;
    assign level_val[5] = candidate_level5;
    assign level_val[6] = candidate_level6;
    assign level_val[7] = candidate_level7;
    
    assign cost_val[0] = candidate_cost0;
    assign cost_val[1] = candidate_cost1;
    assign cost_val[2] = candidate_cost2;
    assign cost_val[3] = candidate_cost3;
    assign cost_val[4] = candidate_cost4;
    assign cost_val[5] = candidate_cost5;
    assign cost_val[6] = candidate_cost6;
    assign cost_val[7] = candidate_cost7;
    
    assign profit_val[0] = profit0;
    assign profit_val[1] = profit1;
    assign profit_val[2] = profit2;
    assign profit_val[3] = profit3;
    assign profit_val[4] = profit4;
    assign profit_val[5] = profit5;
    assign profit_val[6] = profit6;
    assign profit_val[7] = profit7;
    assign profit_val[8] = profit8;
    assign profit_val[9] = profit9;
    assign profit_val[10] = profit10;
    assign profit_val[11] = profit11;
    assign profit_val[12] = profit12;
    assign profit_val[13] = profit13;
    assign profit_val[14] = profit14;
    assign profit_val[15] = profit15;
    
    // State transition and DP update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_profit <= 0;
            level_counter <= 0;
            count_counter <= 0;
            candidate_index <= 0;
            current_level <= 0;
            current_count <= 0;
            current_value <= 0;
            max_temp <= -32'sd1000000000;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INIT;
                        level_counter <= 0;
                        count_counter <= 0;
                        max_temp <= -32'sd1000000000;
                    end
                end
                
                INIT: begin
                    // Initialize DP table
                    if (level_counter < MAX_LEVEL) begin
                        if (count_counter == 0) begin
                            dp[level_counter][0] <= 0;
                        end else begin
                            dp[level_counter][count_counter] <= -32'sd1000000000;
                        end
                        
                        if (count_counter == MAX_COUNT) begin
                            count_counter <= 0;
                            level_counter <= level_counter + 1;
                        end else begin
                            count_counter <= count_counter + 1;
                        end
                    end else begin
                        candidate_index <= num_candidates - 1;
                        state <= PROCESS_CANDIDATE;
                    end
                end
                
                PROCESS_CANDIDATE: begin
                    if (candidate_index[3]) begin // candidate_index < 0 means done
                        state <= FINAL_SCAN;
                        level_counter <= 0;
                        count_counter <= 0;
                    end else begin
                        current_level <= level_val[candidate_index] - 1; // convert to 0-indexed
                        count_counter <= MAX_COUNT;
                        state <= UPDATE_STATE;
                    end
                end
                
                UPDATE_STATE: begin
                    if (count_counter[3]) begin // count < 0, done with this candidate
                        state <= NEXT_CANDIDATE;
                    end else begin
                        if (dp[current_level][count_counter] > -32'sd999999999) begin
                            next_value <= dp[current_level][count_counter] - cost_val[candidate_index] + profit_val[current_level];
                            // We'll compare and update in next state
                            current_count <= count_counter + 1;
                            state <= NEXT_COUNT;
                        end else begin
                            count_counter <= count_counter - 1;
                            state <= UPDATE_STATE;
                        end
                    end
                end
                
                NEXT_COUNT: begin
                    if (next_value > dp[current_level][current_count]) begin
                        dp[current_level][current_count] <= next_value;
                        current_value <= next_value;
                        state <= PROPAGATE;
                    end else begin
                        count_counter <= count_counter - 1;
                        state <= UPDATE_STATE;
                    end
                end
                
                PROPAGATE: begin
                    if (current_count >= 2 && current_level < 15) begin
                        // Propagate fight merging
                        next_value <= current_value + (current_count >> 1) * profit_val[current_level + 1];
                        current_count <= current_count >> 1;
                        current_level <= current_level + 1;
                        // Will update dp in next state
                        state <= NEXT_COUNT; // Reuse NEXT_COUNT to check/update
                    end else begin
                        count_counter <= count_counter - 1;
                        state <= UPDATE_STATE;
                    end
                end
                
                NEXT_CANDIDATE: begin
                    candidate_index <= candidate_index - 1;
                    state <= PROCESS_CANDIDATE;
                end
                
                FINAL_SCAN: begin
                    if (level_counter < MAX_LEVEL) begin
                        if (count_counter < 2) begin
                            if (dp[level_counter][count_counter] > max_temp)
                                max_temp <= dp[level_counter][count_counter];
                            count_counter <= count_counter + 1;
                        end else begin
                            count_counter <= 0;
                            level_counter <= level_counter + 1;
                        end
                    end else begin
                        max_profit <= max_temp;
                        done <= 1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule