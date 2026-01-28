module election_outcome(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [6:0] m,
    input wire [6:0] a,
    input wire [6:0] vote_index,
    input wire [3:0] vote_cand,
    input wire vote_en,
    output reg [2:0] result,
    output reg [3:0] candidate_idx,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_VOTES = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Candidate data storage
    reg [3:0] votes [0:7];  // 4-bit vote counts for up to 8 candidates
    reg [6:0] last_vote [0:7];  // 7-bit last vote time for up to 8 candidates
    reg [2:0] results [0:7];  // 3-bit results for up to 8 candidates

    // Internal registers
    reg [6:0] vote_counter;
    reg [3:0] current_candidate;
    reg [3:0] temp_votes [0:7];
    reg [6:0] remaining_votes;
    reg [3:0] i, j;
    reg [3:0] top_k_count;
    reg [3:0] candidate_in_top_k;
    reg [3:0] candidate_can_reach_top_k;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result <= 3'd0;
            candidate_idx <= 4'd0;
            vote_counter <= 7'd0;
            current_candidate <= 4'd0;
            remaining_votes <= 7'd0;
            i <= 4'd0;
            j <= 4'd0;
            top_k_count <= 4'd0;
            candidate_in_top_k <= 4'd0;
            candidate_can_reach_top_k <= 4'd0;

            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                votes[i] <= 4'd0;
                last_vote[i] <= 7'd0;
                results[i] <= 3'd0;
                temp_votes[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                next_state = IDLE;
                done = 1'b0;
                if (start) begin
                    next_state = LOAD_VOTES;
                    vote_counter = 7'd0;
                end
            end

            LOAD_VOTES: begin
                next_state = LOAD_VOTES;
                if (vote_en && vote_index == vote_counter) begin
                    if (vote_cand > 0 && vote_cand <= n) begin
                        votes[vote_cand - 1] = votes[vote_cand - 1] + 4'd1;
                        last_vote[vote_cand - 1] = vote_counter + 7'd1;
                    end
                    vote_counter = vote_counter + 7'd1;
                    if (vote_counter == a) begin
                        next_state = COMPUTE;
                        current_candidate = 4'd0;
                        remaining_votes = m - a;
                    end
                end
            end

            COMPUTE: begin
                next_state = COMPUTE;
                // Copy votes to temp array
                for (i = 0; i < n; i = i + 1) begin
                    temp_votes[i] = votes[i];
                end

                // Check if current candidate is guaranteed a seat
                candidate_in_top_k = 4'd1;
                for (i = 0; i < n; i = i + 1) begin
                    if (i != current_candidate && temp_votes[i] > temp_votes[current_candidate]) begin
                        temp_votes[i] = temp_votes[i] + remaining_votes;
                        if (temp_votes[i] > temp_votes[current_candidate]) begin
                            candidate_in_top_k = 4'd0;
                        end
                    end
                end

                // Count how many candidates are above current candidate
                top_k_count = 4'd0;
                for (i = 0; i < n; i = i + 1) begin
                    if (i != current_candidate && temp_votes[i] > temp_votes[current_candidate]) begin
                        top_k_count = top_k_count + 4'd1;
                    end
                end

                // Check if current candidate can reach top k
                candidate_can_reach_top_k = 4'd1;
                temp_votes[current_candidate] = temp_votes[current_candidate] + remaining_votes;
                top_k_count = 4'd0;
                for (i = 0; i < n; i = i + 1) begin
                    if (i != current_candidate && temp_votes[i] > temp_votes[current_candidate]) begin
                        top_k_count = top_k_count + 4'd1;
                    end
                end

                if (top_k_count < k) begin
                    candidate_can_reach_top_k = 4'd1;
                end else begin
                    candidate_can_reach_top_k = 4'd0;
                end

                // Determine result
                if (candidate_in_top_k) begin
                    results[current_candidate] = 3'd1;  // Guaranteed seat
                end else if (candidate_can_reach_top_k) begin
                    results[current_candidate] = 3'd2;  // Possible seat
                end else begin
                    results[current_candidate] = 3'd3;  // No chance
                end

                // Move to next candidate
                current_candidate = current_candidate + 4'd1;
                if (current_candidate == n) begin
                    next_state = OUTPUT;
                    current_candidate = 4'd0;
                end
            end

            OUTPUT: begin
                next_state = OUTPUT;
                result = results[current_candidate];
                candidate_idx = current_candidate + 4'd1;
                current_candidate = current_candidate + 4'd1;
                if (current_candidate == n) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
            end
        endcase
    end

endmodule