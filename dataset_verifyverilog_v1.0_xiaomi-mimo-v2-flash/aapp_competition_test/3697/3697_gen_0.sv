module election_outcomes (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [6:0] m,
    input [6:0] a,
    input [6:0] vote_index,
    input [3:0] vote_cand,
    input vote_en,
    output reg [2:0] result,
    output reg [3:0] candidate_idx,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_VOTES = 3'd1;
    localparam [2:0] CHECK_GUARANTEED = 3'd2;
    localparam [2:0] CHECK_POSSIBLE = 3'd3;
    localparam [2:0] STORE_RESULT = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Memory arrays (8 candidates max, 0-7 index)
    reg [3:0] votes [0:7];      // 4 bits per candidate
    reg [6:0] last_vote_time [0:7]; // 7 bits per candidate
    reg [2:0] results [0:7];    // 3 bits per candidate

    // Internal state
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] cand_idx;
    reg [3:0] i; // for loops
    
    // Intermediate calculation registers
    reg [3:0] current_votes;
    reg [3:0] temp_votes;
    reg [6:0] remaining_votes;
    reg [3:0] num_beaters;
    reg [3:0] beat_idx;
    reg [3:0] j; // for beat check
    reg [3:0] temp_idx;
    reg [6:0] last_vote_tmp;
    
    // Output registers
    reg [2:0] next_result;
    reg [3:0] next_candidate_idx;
    reg next_done;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            cand_idx <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            result <= 3'd0;
            candidate_idx <= 4'd0;
            done <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                votes[i] <= 4'd0;
                last_vote_time[i] <= 7'd0;
                results[i] <= 3'd0;
            end
            
            current_votes <= 4'd0;
            temp_votes <= 4'd0;
            remaining_votes <= 7'd0;
            num_beaters <= 4'd0;
            beat_idx <= 4'd0;
            last_vote_tmp <= 7'd0;
            next_result <= 3'd0;
            next_candidate_idx <= 4'd0;
            next_done <= 1'b0;
            
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for loading votes
                        cand_idx <= 4'd0;
                        state <= LOAD_VOTES;
                    end
                end
                
                LOAD_VOTES: begin
                    // Check if we've loaded all 'a' votes
                    if (cand_idx >= a) begin
                        // Done loading, start processing candidates
                        cand_idx <= 4'd0; // Candidate index (0 to n-1)
                        state <= CHECK_GUARANTEED;
                    end else begin
                        // Load vote if enable is high
                        if (vote_en && vote_index == cand_idx) begin
                            // Update votes for this candidate (vote_cand is 1-based)
                            if (vote_cand > 0 && vote_cand <= n) begin
                                votes[vote_cand - 4'd1] <= votes[vote_cand - 4'd1] + 4'd1;
                                last_vote_time[vote_cand - 4'd1] <= cand_idx[6:0];
                            end
                        end
                        cand_idx <= cand_idx + 4'd1;
                    end
                end
                
                CHECK_GUARANTEED: begin
                    // Check if candidate 'cand_idx' is guaranteed a seat
                    // A candidate is guaranteed if they stay in top k even if all 
                    // remaining votes go to candidates that currently beat them
                    
                    if (cand_idx >= n) begin
                        // All candidates processed
                        cand_idx <= 4'd0;
                        state <= FINISH;
                    end else begin
                        // Count how many candidates have more votes than current
                        // (using last vote time as tiebreaker if votes are equal)
                        num_beaters <= 4'd0;
                        beat_idx <= 4'd0;
                        current_votes <= votes[cand_idx];
                        remaining_votes <= m - a;
                        state <= CHECK_POSSIBLE;
                    end
                end
                
                CHECK_POSSIBLE: begin
                    // Count beaters logic
                    if (beat_idx < n) begin
                        if (beat_idx != cand_idx) begin
                            // Check if candidate 'beat_idx' beats 'cand_idx'
                            if (votes[beat_idx] > current_votes || 
                                (votes[beat_idx] == current_votes && last_vote_time[beat_idx] < last_vote_time[cand_idx])) begin
                                num_beaters <= num_beaters + 4'd1;
                            end
                        end
                        beat_idx <= beat_idx + 4'd1;
                    end else begin
                        // Finished counting beaters
                        // Decision logic
                        
                        // 1. Guaranteed: num_beaters < k
                        if (num_beaters < k) begin
                            next_result <= 3'd1;
                            state <= STORE_RESULT;
                        end else begin
                            // 2. Possible: Check if can get into top k
                            // Move all remaining votes to current candidate
                            // and see if they beat enough others
                            
                            // Calculate new votes for current candidate
                            temp_votes <= current_votes + remaining_votes[3:0]; // May truncate, but remaining < 100
                            
                            // Count how many we can beat with all remaining votes
                            beat_idx <= 4'd0;
                            num_beaters <= 4'd0; // reuse as counter for potential beaters
                            state <= STORE_RESULT; // Will handle in STORE_RESULT
                        end
                    end
                end
                
                STORE_RESULT: begin
                    // Determine final result for this candidate
                    if (next_result == 3'd1) begin
                        results[cand_idx] <= 3'd1;
                        result <= 3'd1;
                    end else begin
                        // Check possible case
                        // If adding all remaining votes to current candidate
                        // allows them to beat enough others to be in top k
                        
                        // Recalculate: check how many candidates would have more votes
                        // than current candidate with all remaining votes
                        if (beat_idx < n) begin
                            if (beat_idx != cand_idx) begin
                                // Compare with augmented vote count
                                if (votes[beat_idx] > temp_votes || 
                                    (votes[beat_idx] == temp_votes && last_vote_time[beat_idx] < last_vote_time[cand_idx])) begin
                                    num_beaters <= num_beaters + 4'd1;
                                end
                            end
                            beat_idx <= beat_idx + 4'd1;
                            state <= STORE_RESULT; // Stay in this state
                        end else begin
                            // Done counting beaters for possible case
                            if (num_beaters < k) begin
                                results[cand_idx] <= 3'd2;
                                result <= 3'd2;
                            end else begin
                                results[cand_idx] <= 3'd3;
                                result <= 3'd3;
                            end
                            
                            // Reset for next candidate
                            next_result <= 3'd0;
                        end
                    end
                    
                    // Move to next candidate or finish
                    if (cand_idx + 4'd1 < n) begin
                        cand_idx <= cand_idx + 4'd1;
                        state <= CHECK_GUARANTEED;
                    end else begin
                        state <= FINISH;
                    end
                    
                    candidate_idx <= cand_idx;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule