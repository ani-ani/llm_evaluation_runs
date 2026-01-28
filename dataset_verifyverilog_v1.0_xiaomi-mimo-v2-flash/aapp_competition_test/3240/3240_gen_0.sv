module binary_town_voting(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [6:0] v,
    input wire [15:0] prob_0, prob_1, prob_2, prob_3, prob_4,
    input wire [15:0] prob_5, prob_6, prob_7, prob_8, prob_9,
    input wire [7:0] ballots_0, ballots_1, ballots_2, ballots_3, ballots_4,
    input wire [7:0] ballots_5, ballots_6, ballots_7, ballots_8, ballots_9,
    input wire [3:0] num_voters,
    output reg [7:0] optimal_ballots,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD_PROBS = 3'd1;
localparam [2:0] DP_COMPUTE = 3'd2;
localparam [2:0] EVALUATE = 3'd3;
localparam [2:0] DONE_STATE = 3'd4;

// Registers
reg [2:0] state, next_state;
reg [7:0] prob_dist [0:255];  // 256x8-bit probability table (scaled to 0-255)
reg [7:0] prob_dist_next [0:255];
reg [7:0] prob_dist_old [0:255];
reg [7:0] current_voter_idx;
reg [7:0] current_sum_idx;
reg [7:0] candidate_ballot;
reg [15:0] best_score;
reg [7:0] best_ballots;
reg [7:0] temp_score;
reg [7:0] temp_sum;
reg [7:0] popcount_temp;
reg [7:0] iteration_counter;

// Temporary storage for DP computation
reg [7:0] prob_old;
reg [7:0] prob_old_shifted;
reg [7:0] prob_candidate;
reg [7:0] ballot_value;
reg [7:0] prob_complement;
reg [15:0] prod1, prod2;
reg [15:0] sum_result;

// For evaluation - batch processing
reg [7:0] batch_idx;
reg [7:0] batch_offset;
reg [2:0] popcount_iter;

// Helper signals
wire [7:0] popcount4 [0:3];
wire [7:0] sum_plus_ballot [0:3];

integer i;

// Popcount for 4 parallel sums
assign sum_plus_ballot[0] = current_sum_idx + candidate_ballot;
assign sum_plus_ballot[1] = (current_sum_idx + 8'd1) + candidate_ballot;
assign sum_plus_ballot[2] = (current_sum_idx + 8'd2) + candidate_ballot;
assign sum_plus_ballot[3] = (current_sum_idx + 8'd3) + candidate_ballot;

assign popcount4[0] = (sum_plus_ballot[0][0] + sum_plus_ballot[0][1] + sum_plus_ballot[0][2] + sum_plus_ballot[0][3] + 
                       sum_plus_ballot[0][4] + sum_plus_ballot[0][5] + sum_plus_ballot[0][6] + sum_plus_ballot[0][7]);
assign popcount4[1] = (sum_plus_ballot[1][0] + sum_plus_ballot[1][1] + sum_plus_ballot[1][2] + sum_plus_ballot[1][3] + 
                       sum_plus_ballot[1][4] + sum_plus_ballot[1][5] + sum_plus_ballot[1][6] + sum_plus_ballot[1][7]);
assign popcount4[2] = (sum_plus_ballot[2][0] + sum_plus_ballot[2][1] + sum_plus_ballot[2][2] + sum_plus_ballot[2][3] + 
                       sum_plus_ballot[2][4] + sum_plus_ballot[2][5] + sum_plus_ballot[2][6] + sum_plus_ballot[2][7]);
assign popcount4[3] = (sum_plus_ballot[3][0] + sum_plus_ballot[3][1] + sum_plus_ballot[3][2] + sum_plus_ballot[3][3] + 
                       sum_plus_ballot[3][4] + sum_plus_ballot[3][5] + sum_plus_ballot[3][6] + sum_plus_ballot[3][7]);

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        optimal_ballots <= 8'd0;
        current_voter_idx <= 8'd0;
        current_sum_idx <= 8'd0;
        candidate_ballot <= 8'd0;
        best_score <= 16'd0;
        best_ballots <= 8'd0;
        temp_score <= 8'd0;
        temp_sum <= 8'd0;
        popcount_temp <= 8'd0;
        iteration_counter <= 8'd0;
        batch_idx <= 8'd0;
        batch_offset <= 8'd0;
        popcount_iter <= 3'd0;
        prob_old <= 8'd0;
        prob_old_shifted <= 8'd0;
        prob_candidate <= 8'd0;
        ballot_value <= 8'd0;
        prob_complement <= 8'd0;
        prod1 <= 16'd0;
        prod2 <= 16'd0;
        sum_result <= 16'd0;
        
        for (i = 0; i < 256; i = i + 1) begin
            prob_dist[i] <= 8'd0;
            prob_dist_next[i] <= 8'd0;
            prob_dist_old[i] <= 8'd0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                current_voter_idx <= 8'd0;
                current_sum_idx <= 8'd0;
                candidate_ballot <= 8'd0;
                best_score <= 16'd0;
                best_ballots <= 8'd0;
                iteration_counter <= 8'd0;
                batch_idx <= 8'd0;
                popcount_iter <= 3'd0;
            end
            
            LOAD_PROBS: begin
                // Initialize probability distribution
                // P[0] = 256 (1.0), others = 0
                if (current_sum_idx == 8'd0) begin
                    prob_dist[current_sum_idx] <= 8'd255;  // Scale 1.0 to 255
                end else begin
                    prob_dist[current_sum_idx] <= 8'd0;
                end
                current_sum_idx <= current_sum_idx + 8'd1;
            end
            
            DP_COMPUTE: begin
                // Update DP for current voter
                // P_new[s] = P_old[s] * (1-p) + P_old[s - b_i] * p
                // where p is scaled to 0-255
                
                prob_old <= prob_dist_old[current_sum_idx];
                prob_old_shifted <= prob_dist_old[(current_sum_idx - ballot_value) & 8'hFF];
                
                // Get probability for current voter
                case (current_voter_idx)
                    8'd0: prob_candidate <= prob_0[15:8];
                    8'd1: prob_candidate <= prob_1[15:8];
                    8'd2: prob_candidate <= prob_2[15:8];
                    8'd3: prob_candidate <= prob_3[15:8];
                    8'd4: prob_candidate <= prob_4[15:8];
                    8'd5: prob_candidate <= prob_5[15:8];
                    8'd6: prob_candidate <= prob_6[15:8];
                    8'd7: prob_candidate <= prob_7[15:8];
                    8'd8: prob_candidate <= prob_8[15:8];
                    8'd9: prob_candidate <= prob_9[15:8];
                    default: prob_candidate <= 8'd0;
                endcase
                
                // Get ballot value
                case (current_voter_idx)
                    8'd0: ballot_value <= ballots_0;
                    8'd1: ballot_value <= ballots_1;
                    8'd2: ballot_value <= ballots_2;
                    8'd3: ballot_value <= ballots_3;
                    8'd4: ballot_value <= ballots_4;
                    8'd5: ballot_value <= ballots_5;
                    8'd6: ballot_value <= ballots_6;
                    8'd7: ballot_value <= ballots_7;
                    8'd8: ballot_value <= ballots_8;
                    8'd9: ballot_value <= ballots_9;
                    default: ballot_value <= 8'd0;
                endcase
                
                // Compute probabilities (scaled to 8-bit)
                // prob_complement = 255 - prob_candidate (approx 1-p)
                prob_complement <= 8'd255 - prob_candidate;
                
                // prod1 = prob_old * prob_complement
                prod1 <= prob_old * prob_complement;
                // prod2 = prob_old_shifted * prob_candidate
                prod2 <= prob_old_shifted * prob_candidate;
                
                // sum and shift right by 8
                sum_result <= prod1 + prod2;
                prob_dist_next[current_sum_idx] <= sum_result[15:8];
                
                current_sum_idx <= current_sum_idx + 8'd1;
            end
            
            EVALUATE: begin
                // For each candidate ballot b_v (0-255)
                // Compute expected score
                
                if (popcount_iter == 3'd0) begin
                    // Load probability for batch start
                    if (batch_offset < 8'd252) begin
                        temp_score <= 8'd0;  // Reset temp score for new batch
                    end
                end
                
                // Add weighted popcounts for 4 sums
                if (batch_offset < 8'd252) begin
                    temp_score <= temp_score + ((prob_dist[batch_offset] * popcount4[0]) >> 8) +
                                           ((prob_dist[batch_offset + 8'd1] * popcount4[1]) >> 8) +
                                           ((prob_dist[batch_offset + 8'd2] * popcount4[2]) >> 8) +
                                           ((prob_dist[batch_offset + 8'd3] * popcount4[3]) >> 8);
                end
                
                popcount_iter <= popcount_iter + 3'd1;
                if (popcount_iter == 3'd7) begin
                    // Finished batch
                    batch_offset <= batch_offset + 8'd4;
                    popcount_iter <= 3'd0;
                end
                
                // When finished evaluating one candidate
                if (batch_offset >= 8'd252 && popcount_iter == 3'd7) begin
                    // Check if this candidate is better
                    if (temp_score > best_score) begin
                        best_score <= temp_score;
                        best_ballots <= candidate_ballot;
                    end
                    // Next candidate
                    candidate_ballot <= candidate_ballot + 8'd1;
                    batch_offset <= 8'd0;
                    temp_score <= 8'd0;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                optimal_ballots <= best_ballots;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) next_state = LOAD_PROBS;
        end
        
        LOAD_PROBS: begin
            if (current_sum_idx == 8'd255) begin
                next_state = DP_COMPUTE;
            end
        end
        
        DP_COMPUTE: begin
            if (current_sum_idx == 8'd255 && current_voter_idx < num_voters) begin
                // Move to next voter or finish DP
                if (current_voter_idx + 8'd1 >= num_voters) begin
                    next_state = EVALUATE;
                end else begin
                    // Copy next state
                    next_state = DP_COMPUTE;
                end
            end
        end
        
        EVALUATE: begin
            // Check if all candidates evaluated
            if (candidate_ballot == 8'd255 && batch_offset >= 8'd252 && popcount_iter == 3'd7) begin
                next_state = DONE_STATE;
            end
        end
        
        DONE_STATE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Copy prob_dist to prob_dist_old when starting new voter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 256; i = i + 1) begin
            prob_dist_old[i] <= 8'd0;
        end
    end else begin
        if (state == DP_COMPUTE && current_sum_idx == 8'd0 && current_voter_idx < num_voters) begin
            // Copy current prob_dist to old for next iteration
            for (i = 0; i < 256; i = i + 1) begin
                prob_dist_old[i] <= prob_dist[i];
            end
        end
    end
end

endmodule