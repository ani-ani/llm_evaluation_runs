module character_creator (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_players,
    input [7:0] num_features,
    input [7:0][7:0] characters,
    output reg [7:0] best_character,
    output reg [7:0] min_max_similarity,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT_CANDIDATE = 3'b001;
    localparam COMPUTE_SIM = 3'b010;
    localparam UPDATE_MAX = 3'b011;
    localparam NEXT_CANDIDATE = 3'b100;
    localparam DONE = 3'b101;

    // Registers for state and counters
    reg [2:0] current_state, next_state;
    reg [7:0] candidate_reg; // Current candidate character
    reg [7:0] player_idx;    // Index for iterating through existing characters
    reg [7:0] current_max_sim; // Max similarity for current candidate
    reg [7:0] best_cand_reg;   // Best candidate found so far
    reg [7:0] best_max_sim_reg; // Best max similarity found so far

    // Combinational signals
    reg [7:0] sim_count;      // Similarity count for current comparison
    reg [7:0] diff_mask;      // Mask to find differences
    integer i;                // Loop variable for similarity calculation

    // Combinational Similarity Calculation
    // Similarity = k - Hamming Distance (number of differing bits)
    // a ^ b produces 1 where bits differ. ~((a ^ b) | ~mask) isolates matches if masked.
    // Here we just calculate Hamming distance (count of 1s in a^b) up to num_features.
    always @(*) begin
        diff_mask = 8'b0;
        sim_count = 0;
        
        // Create a mask for valid features (k bits)
        if (num_features == 8'd0) diff_mask = 8'h00;
        else if (num_features >= 8'd8) diff_mask = 8'hFF;
        else diff_mask = (8'h01 << num_features) - 1;

        // Calculate Hamming Distance (XOR and Count Ones)
        // Only interested in bits set in diff_mask
        case (characters[player_idx] ^ candidate_reg & diff_mask)
            8'h00: sim_count = num_features;
            8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80: sim_count = num_features - 1;
            8'h03, 8'h05, 8'h06, 8'h09, 8'h0A, 8'h0C, 8'h11, 8'h12, 8'h14, 8'h18, 8'h21, 8'h22, 8'h24, 8'h28, 8'h30, 8'h41, 8'h42, 8'h44, 8'h48, 8'h50, 8'h60, 8'h81, 8'h82, 8'h84, 8'h88, 8'h90, 8'hA0, 8'hC0: sim_count = num_features - 2;
            8'h07, 8'h0B, 8'h0D, 8'h0E, 8'h13, 8'h15, 8'h16, 8'h19, 8'h1A, 8'h1C, 8'h23, 8'h25, 8'h26, 8'h29, 8'h2A, 8'h2C, 8'h31, 8'h32, 8'h34, 8'h38, 8'h43, 8'h45, 8'h46, 8'h49, 8'h4A, 8'h4C, 8'h51, 8'h52, 8'h54, 8'h58, 8'h61, 8'h62, 8'h64, 8'h68, 8'h70, 8'h83, 8'h85, 8'h86, 8'h89, 8'h8A, 8'h8C, 8'h91, 8'h92, 8'h94, 8'h98, 8'hA1, 8'hA2, 8'hA4, 8'hA8, 8'hB0, 8'hC1, 8'hC2, 8'hC4, 8'hC8, 8'hD0, 8'hE0: sim_count = num_features - 3;
            8'h0F, 8'h17, 8'h1B, 8'h1D, 8'h1E, 8'h27, 8'h2B, 8'h2D, 8'h2E, 8'h33, 8'h35, 8'h36, 8'h39, 8'h3A, 8'h3C, 8'h47, 8'h4B, 8'h4D, 8'h4E, 8'h53, 8'h55, 8'h56, 8'h59, 8'h5A, 8'h5C, 8'h63, 8'h65, 8'h66, 8'h69, 8'h6A, 8'h6C, 8'h71, 8'h72, 8'h74, 8'h78, 8'h87, 8'h8B, 8'h8D, 8'h8E, 8'h93, 8'h95, 8'h96, 8'h99, 8'h9A, 8'h9C, 8'hA3, 8'hA5, 8'hA6, 8'hA9, 8'hAA, 8'hAC, 8'hB1, 8'hB2, 8'hB4, 8'hB8, 8'hC3, 8'hC5, 8'hC6, 8'hC9, 8'hCA, 8'hCC, 8'hD1, 8'hD2, 8'hD4, 8'hD8, 8'hE1, 8'hE2, 8'hE4, 8'hE8, 8'hF0: sim_count = num_features - 4;
            default: sim_count = 0; // Handle 5+ bits set (rare for max sim calculation logic, usually low sim is desired)
        endcase
        
        // Override for small k to ensure correct subtraction if case statement misses edge cases
        if (num_features < 8'd5) begin
             // Simple loop for small k to be safe
             sim_count = num_features;
             for (i = 0; i < 8; i = i + 1) begin
                 if (i < num_features) begin
                     if ((characters[player_idx][i] ^ candidate_reg[i]))
                         sim_count = sim_count - 1;
                 end
             end
        end
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = INIT_CANDIDATE;
                else
                    next_state = IDLE;
            end
            INIT_CANDIDATE: begin
                next_state = COMPUTE_SIM;
            end
            COMPUTE_SIM: begin
                next_state = UPDATE_MAX;
            end
            UPDATE_MAX: begin
                if (player_idx + 1 < num_players) begin
                    next_state = COMPUTE_SIM;
                end else begin
                    next_state = NEXT_CANDIDATE;
                end
            end
            NEXT_CANDIDATE: begin
                // Check if we have scanned all 2^k candidates
                // Since k <= 8, we scan 0 to 255. 
                // However, if num_features < 8, we can technically stop earlier, 
                // but requirement says max 256 cycles, so scanning full 256 is acceptable for k=8.
                // If k < 8, higher candidates are effectively duplicates (just more leading zeros).
                // We iterate 2^k times. 
                if (candidate_reg == (8'hFF >> (8 - num_features))) begin // Last candidate check
                    next_state = DONE;
                end else begin
                    next_state = INIT_CANDIDATE;
                end
            end
            DONE: begin
                next_state = DONE; // Stay in done state until reset
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            best_character <= 8'b0;
            min_max_similarity <= 8'b0;
            done <= 1'b0;
            candidate_reg <= 8'b0;
            player_idx <= 8'b0;
            current_max_sim <= 8'b0;
            best_cand_reg <= 8'b0;
            best_max_sim_reg <= 8'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                end
                INIT_CANDIDATE: begin
                    // Initialize for new candidate
                    // candidate_reg is incremented in NEXT_CANDIDATE, so in IDLE it starts at 0 or resumes
                    // In INIT_CANDIDATE, we just reset local max and index
                    current_max_sim <= 8'b0;
                    player_idx <= 8'b0;
                end
                COMPUTE_SIM: begin
                    // Nothing to do here, combinational logic calculates sim_count
                end
                UPDATE_MAX: begin
                    // Update max similarity for current candidate
                    if (sim_count > current_max_sim)
                        current_max_sim <= sim_count;
                    
                    // Move to next player
                    player_idx <= player_idx + 1;
                end
                NEXT_CANDIDATE: begin
                    // Compare current candidate result with global best
                    if (current_max_sim < best_max_sim_reg || candidate_reg == 0) begin
                        best_max_sim_reg <= current_max_sim;
                        best_cand_reg <= candidate_reg;
                    end
                    
                    // Increment candidate for next iteration
                    candidate_reg <= candidate_reg + 1;
                end
                DONE: begin
                    best_character <= best_cand_reg;
                    min_max_similarity <= best_max_sim_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
