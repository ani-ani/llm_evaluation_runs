module WordGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg win,
    output reg [7:0] word_0,
    output reg [7:0] word_1,
    output reg [7:0] word_2,
    output reg [7:0] word_3,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] RESET_STATE   = 4'd1;
    localparam [3:0] FETCH_ARR     = 4'd2;
    localparam [3:0] INIT_PERM      = 4'd3;
    localparam [3:0] SIMULATE_START = 4'd4;
    localparam [3:0] SIMULATE_ROUND = 4'd5;
    localparam [3:0] CHECK_WIN      = 4'd6;
    localparam [3:0] UPDATE_BEST    = 4'd7;
    localparam [3:0] NEXT_PERM      = 4'd8;
    localparam [3:0] OUTPUT_STATE   = 4'd9;
    localparam [3:0] FINISH         = 4'd10;

    reg [3:0] state, next_state;
    
    // Arrays to store input letters
    reg [7:0] letters [0:7];
    
    // Permutation generation for Slavko's picks (3! = 6 permutations for picking order)
    // Actually, we need to pick 4 letters out of 8 for Slavko, which is C(8,4) = 70 combinations
    // For each combination, we need to consider the order of picking (4! = 24)
    // Total: 70 * 24 = 1680 sequences
    // However, since we process sequentially, we can generate combinations dynamically
    
    reg [2:0] pick_idx; // Index of pick in sequence (0 to 3)
    reg [2:0] letter_idx; // Index of letter being considered
    reg [3:0] slavko_indices [0:3]; // Indices of Slavko's picks
    reg [3:0] mirko_indices [0:3]; // Indices of Mirko's picks
    reg [7:0] mask; // Bitmask of remaining letters (bit 0 = letter 0, etc.)
    
    // For tracking best word
    reg [7:0] best_word_0, best_word_1, best_word_2, best_word_3;
    reg best_found;
    reg current_wins;
    
    // Cycle counter for timeout
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd1000;
    
    // For generating all combinations of 4 indices from 0..7
    // We'll iterate through all 70 combinations using nested loops
    reg [2:0] comb_idx0, comb_idx1, comb_idx2, comb_idx3;
    reg [3:0] current_comb [0:3];
    reg [2:0] perm_idx0, perm_idx1, perm_idx2, perm_idx3;
    reg [3:0] current_perm [0:3];
    
    // Simulation state
    reg [2:0] round_num;
    reg [3:0] current_slavko_indices [0:3];
    reg [3:0] current_mirko_indices [0:3];
    
    // For comparison
    integer i;
    reg comparison_result;
    reg temp_wins;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            win <= 1'b0;
            word_0 <= 8'd0;
            word_1 <= 8'd0;
            word_2 <= 8'd0;
            word_3 <= 8'd0;
            done <= 1'b0;
            cycle_count <= 12'd0;
            
            // Reset all arrays
            for (i = 0; i < 8; i = i + 1) begin
                letters[i] <= 8'd0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                slavko_indices[i] <= 4'd0;
                mirko_indices[i] <= 4'd0;
                best_word_0 <= 8'd0;
                best_word_1 <= 8'd0;
                best_word_2 <= 8'd0;
                best_word_3 <= 8'd0;
                current_comb[i] <= 4'd0;
                current_perm[i] <= 4'd0;
                current_slavko_indices[i] <= 4'd0;
                current_mirko_indices[i] <= 4'd0;
            end
            best_found <= 1'b0;
            current_wins <= 1'b0;
            pick_idx <= 3'd0;
            letter_idx <= 3'd0;
            mask <= 8'd0;
            round_num <= 3'd0;
            comb_idx0 <= 3'd0;
            comb_idx1 <= 3'd1;
            comb_idx2 <= 3'd2;
            comb_idx3 <= 3'd3;
            perm_idx0 <= 3'd0;
            perm_idx1 <= 3'd1;
            perm_idx2 <= 3'd2;
            perm_idx3 <= 3'd3;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 12'd0;
                    if (start) begin
                        state <= FETCH_ARR;
                    end
                end
                
                FETCH_ARR: begin
                    letters[0] <= arr_0;
                    letters[1] <= arr_1;
                    letters[2] <= arr_2;
                    letters[3] <= arr_3;
                    letters[4] <= arr_4;
                    letters[5] <= arr_5;
                    letters[6] <= arr_6;
                    letters[7] <= arr_7;
                    state <= INIT_PERM;
                end
                
                INIT_PERM: begin
                    // Reset best tracking
                    best_found <= 1'b0;
                    win <= 1'b0;
                    best_word_0 <= 8'd0;
                    best_word_1 <= 8'd0;
                    best_word_2 <= 8'd0;
                    best_word_3 <= 8'd0;
                    
                    // Initialize combination indices (C(8,4) generation)
                    comb_idx0 <= 3'd0;
                    comb_idx1 <= 3'd1;
                    comb_idx2 <= 3'd2;
                    comb_idx3 <= 3'd3;
                    perm_idx0 <= 3'd0;
                    perm_idx1 <= 3'd1;
                    perm_idx2 <= 3'd2;
                    perm_idx3 <= 3'd3;
                    state <= SIMULATE_START;
                end
                
                SIMULATE_START: begin
                    // Set up current combination
                    current_comb[0] <= {1'b0, comb_idx0};
                    current_comb[1] <= {1'b0, comb_idx1};
                    current_comb[2] <= {1'b0, comb_idx2};
                    current_comb[3] <= {1'b0, comb_idx3};
                    
                    // Initialize permutation for this combination
                    perm_idx0 <= 3'd0;
                    perm_idx1 <= 3'd1;
                    perm_idx2 <= 3'd2;
                    perm_idx3 <= 3'd3;
                    state <= SIMULATE_ROUND;
                end
                
                SIMULATE_ROUND: begin
                    // Generate current permutation from combination
                    case (perm_idx0)
                        3'd0: current_perm[0] <= current_comb[0];
                        3'd1: current_perm[0] <= current_comb[1];
                        3'd2: current_perm[0] <= current_comb[2];
                        3'd3: current_perm[0] <= current_comb[3];
                        default: current_perm[0] <= current_comb[0];
                    endcase
                    case (perm_idx1)
                        3'd0: current_perm[1] <= current_comb[0];
                        3'd1: current_perm[1] <= current_comb[1];
                        3'd2: current_perm[1] <= current_comb[2];
                        3'd3: current_perm[1] <= current_comb[3];
                        default: current_perm[1] <= current_comb[1];
                    endcase
                    case (perm_idx2)
                        3'd0: current_perm[2] <= current_comb[0];
                        3'd1: current_perm[2] <= current_comb[1];
                        3'd2: current_perm[2] <= current_comb[2];
                        3'd3: current_perm[2] <= current_comb[3];
                        default: current_perm[2] <= current_comb[2];
                    endcase
                    case (perm_idx3)
                        3'd0: current_perm[3] <= current_comb[0];
                        3'd1: current_perm[3] <= current_comb[1];
                        3'd2: current_perm[3] <= current_comb[2];
                        3'd3: current_perm[3] <= current_comb[3];
                        default: current_perm[3] <= current_comb[3];
                    endcase
                    
                    // Initialize simulation
                    mask <= 8'hFF;
                    round_num <= 3'd0;
                    temp_wins <= 1'b0;
                    state <= CHECK_WIN;
                end
                
                CHECK_WIN: begin
                    if (round_num < 4) begin
                        // Mirko picks rightmost remaining letter
                        // Find highest index bit set in mask
                        if (mask[7]) current_mirko_indices[round_num] <= 4'd7;
                        else if (mask[6]) current_mirko_indices[round_num] <= 4'd6;
                        else if (mask[5]) current_mirko_indices[round_num] <= 4'd5;
                        else if (mask[4]) current_mirko_indices[round_num] <= 4'd4;
                        else if (mask[3]) current_mirko_indices[round_num] <= 4'd3;
                        else if (mask[2]) current_mirko_indices[round_num] <= 4'd2;
                        else if (mask[1]) current_mirko_indices[round_num] <= 4'd1;
                        else current_mirko_indices[round_num] <= 4'd0;
                        
                        // Update mask after Mirko picks
                        if (mask[7]) mask <= mask & 8'h7F;
                        else if (mask[6]) mask <= mask & 8'hBF;
                        else if (mask[5]) mask <= mask & 8'hDF;
                        else if (mask[4]) mask <= mask & 8'hEF;
                        else if (mask[3]) mask <= mask & 8'hF7;
                        else if (mask[2]) mask <= mask & 8'hFB;
                        else if (mask[1]) mask <= mask & 8'hFD;
                        else mask <= mask & 8'hFE;
                        
                        // Slavko picks based on current permutation
                        current_slavko_indices[round_num] <= current_perm[round_num];
                        
                        // Remove Slavko's pick from mask
                        if (current_perm[round_num] == 4'd0) mask <= mask & 8'hFE;
                        else if (current_perm[round_num] == 4'd1) mask <= mask & 8'hFD;
                        else if (current_perm[round_num] == 4'd2) mask <= mask & 8'hFB;
                        else if (current_perm[round_num] == 4'd3) mask <= mask & 8'hF7;
                        else if (current_perm[round_num] == 4'd4) mask <= mask & 8'hEF;
                        else if (current_perm[round_num] == 4'd5) mask <= mask & 8'hDF;
                        else if (current_perm[round_num] == 4'd6) mask <= mask & 8'hBF;
                        else if (current_perm[round_num] == 4'd7) mask <= mask & 8'h7F;
                        
                        round_num <= round_num + 3'd1;
                    end else begin
                        // Simulation complete, check if this sequence wins
                        // Compare Slavko's word with Mirko's word lexicographically
                        // Current word is from current_slavko_indices
                        
                        if (!best_found) begin
                            // First valid sequence, initialize best
                            best_found <= 1'b1;
                            best_word_0 <= letters[current_slavko_indices[0]];
                            best_word_1 <= letters[current_slavko_indices[1]];
                            best_word_2 <= letters[current_slavko_indices[2]];
                            best_word_3 <= letters[current_slavko_indices[3]];
                        end else begin
                            // Compare current word with best word
                            if (letters[current_slavko_indices[0]] < best_word_0) begin
                                best_word_0 <= letters[current_slavko_indices[0]];
                                best_word_1 <= letters[current_slavko_indices[1]];
                                best_word_2 <= letters[current_slavko_indices[2]];
                                best_word_3 <= letters[current_slavko_indices[3]];
                            end else if (letters[current_slavko_indices[0]] == best_word_0) begin
                                if (letters[current_slavko_indices[1]] < best_word_1) begin
                                    best_word_0 <= letters[current_slavko_indices[0]];
                                    best_word_1 <= letters[current_slavko_indices[1]];
                                    best_word_2 <= letters[current_slavko_indices[2]];
                                    best_word_3 <= letters[current_slavko_indices[3]];
                                end else if (letters[current_slavko_indices[1]] == best_word_1) begin
                                    if (letters[current_slavko_indices[2]] < best_word_2) begin
                                        best_word_0 <= letters[current_slavko_indices[0]];
                                        best_word_1 <= letters[current_slavko_indices[1]];
                                        best_word_2 <= letters[current_slavko_indices[2]];
                                        best_word_3 <= letters[current_slavko_indices[3]];
                                    end else if (letters[current_slavko_indices[2]] == best_word_2) begin
                                        if (letters[current_slavko_indices[3]] < best_word_3) begin
                                            best_word_0 <= letters[current_slavko_indices[0]];
                                            best_word_1 <= letters[current_slavko_indices[1]];
                                            best_word_2 <= letters[current_slavko_indices[2]];
                                            best_word_3 <= letters[current_slavko_indices[3]];
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Check if this sequence wins
                        // Compare lexicographically
                        temp_wins <= 1'b0;
                        if (letters[current_slavko_indices[0]] < letters[current_mirko_indices[0]]) begin
                            temp_wins <= 1'b1;
                        end else if (letters[current_slavko_indices[0]] == letters[current_mirko_indices[0]]) begin
                            if (letters[current_slavko_indices[1]] < letters[current_mirko_indices[1]]) begin
                                temp_wins <= 1'b1;
                            end else if (letters[current_slavko_indices[1]] == letters[current_mirko_indices[1]]) begin
                                if (letters[current_slavko_indices[2]] < letters[current_mirko_indices[2]]) begin
                                    temp_wins <= 1'b1;
                                end else if (letters[current_slavko_indices[2]] == letters[current_mirko_indices[2]]) begin
                                    if (letters[current_slavko_indices[3]] < letters[current_mirko_indices[3]]) begin
                                        temp_wins <= 1'b1;
                                    end
                                end
                            end
                        end
                        
                        state <= UPDATE_BEST;
                    end
                end
                
                UPDATE_BEST: begin
                    // Update global win status
                    if (temp_wins) begin
                        win <= 1'b1;
                    end
                    state <= NEXT_PERM;
                end
                
                NEXT_PERM: begin
                    // Generate next permutation
                    // Simple counter-based permutation generation for 4 elements
                    if (perm_idx0 < 3) begin
                        perm_idx0 <= perm_idx0 + 3'd1;
                        perm_idx1 <= 3'd1;
                        perm_idx2 <= 3'd2;
                        perm_idx3 <= 3'd3;
                        state <= SIMULATE_ROUND;
                    end else if (perm_idx1 < 3) begin
                        perm_idx0 <= 3'd0;
                        perm_idx1 <= perm_idx1 + 3'd1;
                        perm_idx2 <= 3'd2;
                        perm_idx3 <= 3'd3;
                        state <= SIMULATE_ROUND;
                    end else if (perm_idx2 < 3) begin
                        perm_idx0 <= 3'd0;
                        perm_idx1 <= 3'd1;
                        perm_idx2 <= perm_idx2 + 3'd1;
                        perm_idx3 <= 3'd3;
                        state <= SIMULATE_ROUND;
                    end else if (perm_idx3 < 3) begin
                        perm_idx0 <= 3'd0;
                        perm_idx1 <= 3'd1;
                        perm_idx2 <= 3'd2;
                        perm_idx3 <= perm_idx3 + 3'd1;
                        state <= SIMULATE_ROUND;
                    end else begin
                        // Done all permutations for this combination, move to next combination
                        state <= NEXT_COMB;
                    end
                end
                
                NEXT_COMB: begin
                    // Generate next combination C(8,4)
                    if (comb_idx3 < 7) begin
                        comb_idx3 <= comb_idx3 + 3'd1;
                        comb_idx2 <= comb_idx2;
                        comb_idx1 <= comb_idx1;
                        comb_idx0 <= comb_idx0;
                        state <= SIMULATE_START;
                    end else if (comb_idx2 < 6) begin
                        comb_idx2 <= comb_idx2 + 3'd1;
                        comb_idx3 <= comb_idx2 + 3'd2;
                        comb_idx1 <= comb_idx1;
                        comb_idx0 <= comb_idx0;
                        state <= SIMULATE_START;
                    end else if (comb_idx1 < 5) begin
                        comb_idx1 <= comb_idx1 + 3'd1;
                        comb_idx2 <= comb_idx1 + 3'd2;
                        comb_idx3 <= comb_idx1 + 3'd3;
                        comb_idx0 <= comb_idx0;
                        state <= SIMULATE_START;
                    end else if (comb_idx0 < 4) begin
                        comb_idx0 <= comb_idx0 + 3'd1;
                        comb_idx1 <= comb_idx0 + 3'd1;
                        comb_idx2 <= comb_idx0 + 3'd2;
                        comb_idx3 <= comb_idx0 + 3'd3;
                        state <= SIMULATE_START;
                    end else begin
                        // Done all combinations
                        state <= OUTPUT_STATE;
                    end
                end
                
                OUTPUT_STATE: begin
                    // Assign outputs from best word
                    word_0 <= best_word_0;
                    word_1 <= best_word_1;
                    word_2 <= best_word_2;
                    word_3 <= best_word_3;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        // Timeout protection
                        done <= 1'b1;
                    end else if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Increment cycle counter
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 12'd1;
            end
        end
    end

endmodule