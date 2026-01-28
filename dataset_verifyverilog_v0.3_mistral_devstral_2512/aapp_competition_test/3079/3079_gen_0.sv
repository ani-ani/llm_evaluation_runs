module WordGame(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg win,
    output reg [7:0] word_0,
    output reg [7:0] word_1,
    output reg [7:0] word_2,
    output reg [7:0] word_3,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Internal registers
    reg [2:0] state;
    reg [7:0] letters [0:7];
    reg [7:0] current_word [0:3];
    reg [7:0] best_word [0:3];
    reg [7:0] mirko_word [0:3];
    reg [7:0] mask;
    reg [7:0] sequence [0:3];
    reg [7:0] seq_index;
    reg [7:0] round;
    reg [7:0] pick_index;
    reg [7:0] cycle_count;
    reg [7:0] total_cycles;
    reg found_win;
    reg [7:0] i, j, k, l;
    
    // Constants
    localparam [7:0] MAX_CYCLES = 8'd1000;
    
    // Initialize letters array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            letters[0] <= 8'd0;
            letters[1] <= 8'd0;
            letters[2] <= 8'd0;
            letters[3] <= 8'd0;
            letters[4] <= 8'd0;
            letters[5] <= 8'd0;
            letters[6] <= 8'd0;
            letters[7] <= 8'd0;
        end else begin
            letters[0] <= arr_0;
            letters[1] <= arr_1;
            letters[2] <= arr_2;
            letters[3] <= arr_3;
            letters[4] <= arr_4;
            letters[5] <= arr_5;
            letters[6] <= arr_6;
            letters[7] <= arr_7;
        end
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            win <= 1'b0;
            word_0 <= 8'd0;
            word_1 <= 8'd0;
            word_2 <= 8'd0;
            word_3 <= 8'd0;
            cycle_count <= 8'd0;
            total_cycles <= 8'd0;
            found_win <= 1'b0;
            
            // Initialize best_word to maximum possible value
            best_word[0] <= 8'hFF;
            best_word[1] <= 8'hFF;
            best_word[2] <= 8'hFF;
            best_word[3] <= 8'hFF;
            
            // Initialize sequence indices
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            l <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    win <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        cycle_count <= 8'd0;
                        total_cycles <= 8'd0;
                        found_win <= 1'b0;
                        
                        // Initialize best_word to maximum possible value
                        best_word[0] <= 8'hFF;
                        best_word[1] <= 8'hFF;
                        best_word[2] <= 8'hFF;
                        best_word[3] <= 8'hFF;
                        
                        // Initialize sequence indices
                        i <= 8'd0;
                        j <= 8'd0;
                        k <= 8'd0;
                        l <= 8'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Generate all possible sequences
                    // Sequence: [i, j, k, l] where i, j, k, l are distinct indices
                    // We'll iterate through all combinations
                    
                    // Initialize mask for this sequence
                    mask <= 8'hFF; // All letters available initially
                    
                    // Round 1: Mirko picks rightmost available
                    round <= 8'd0;
                    pick_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            // This is the rightmost available
                            mirko_word[round] <= letters[pick_index];
                            mask[pick_index] <= 1'b0;
                            break;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Slavko picks i-th available letter
                    pick_index <= 8'd0;
                    seq_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            if (seq_index == i) begin
                                current_word[round] <= letters[pick_index];
                                sequence[round] <= pick_index;
                                mask[pick_index] <= 1'b0;
                                break;
                            end
                            seq_index <= seq_index + 8'd1;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Round 2: Mirko picks rightmost available
                    round <= 8'd1;
                    pick_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            mirko_word[round] <= letters[pick_index];
                            mask[pick_index] <= 1'b0;
                            break;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Slavko picks j-th available letter
                    pick_index <= 8'd0;
                    seq_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            if (seq_index == j) begin
                                current_word[round] <= letters[pick_index];
                                sequence[round] <= pick_index;
                                mask[pick_index] <= 1'b0;
                                break;
                            end
                            seq_index <= seq_index + 8'd1;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Round 3: Mirko picks rightmost available
                    round <= 8'd2;
                    pick_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            mirko_word[round] <= letters[pick_index];
                            mask[pick_index] <= 1'b0;
                            break;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Slavko picks k-th available letter
                    pick_index <= 8'd0;
                    seq_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            if (seq_index == k) begin
                                current_word[round] <= letters[pick_index];
                                sequence[round] <= pick_index;
                                mask[pick_index] <= 1'b0;
                                break;
                            end
                            seq_index <= seq_index + 8'd1;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Round 4: Mirko picks rightmost available
                    round <= 8'd3;
                    pick_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            mirko_word[round] <= letters[pick_index];
                            mask[pick_index] <= 1'b0;
                            break;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Slavko picks l-th available letter
                    pick_index <= 8'd0;
                    seq_index <= 8'd0;
                    while (pick_index < 8) begin
                        if (mask[pick_index]) begin
                            if (seq_index == l) begin
                                current_word[round] <= letters[pick_index];
                                sequence[round] <= pick_index;
                                mask[pick_index] <= 1'b0;
                                break;
                            end
                            seq_index <= seq_index + 8'd1;
                        end
                        pick_index <= pick_index + 8'd1;
                    end
                    
                    // Check if current_word is better than best_word
                    if (current_word[0] < best_word[0] ||
                        (current_word[0] == best_word[0] && current_word[1] < best_word[1]) ||
                        (current_word[0] == best_word[0] && current_word[1] == best_word[1] && current_word[2] < best_word[2]) ||
                        (current_word[0] == best_word[0] && current_word[1] == best_word[1] && current_word[2] == best_word[2] && current_word[3] < best_word[3])) begin
                        best_word[0] <= current_word[0];
                        best_word[1] <= current_word[1];
                        best_word[2] <= current_word[2];
                        best_word[3] <= current_word[3];
                    end
                    
                    // Check if current_word < mirko_word
                    if (current_word[0] < mirko_word[0] ||
                        (current_word[0] == mirko_word[0] && current_word[1] < mirko_word[1]) ||
                        (current_word[0] == mirko_word[0] && current_word[1] == mirko_word[1] && current_word[2] < mirko_word[2]) ||
                        (current_word[0] == mirko_word[0] && current_word[1] == mirko_word[1] && current_word[2] == mirko_word[2] && current_word[3] < mirko_word[3])) begin
                        found_win <= 1'b1;
                    end
                    
                    // Update sequence indices
                    l <= l + 8'd1;
                    if (l >= 8) begin
                        l <= 8'd0;
                        k <= k + 8'd1;
                        if (k >= 8) begin
                            k <= 8'd0;
                            j <= j + 8'd1;
                            if (j >= 8) begin
                                j <= 8'd0;
                                i <= i + 8'd1;
                                if (i >= 8) begin
                                    i <= 8'd0;
                                    state <= FINISH;
                                end
                            end
                        end
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    win <= found_win;
                    word_0 <= best_word[0];
                    word_1 <= best_word[1];
                    word_2 <= best_word[2];
                    word_3 <= best_word[3];
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    win <= 1'b0;
                    word_0 <= 8'd0;
                    word_1 <= 8'd0;
                    word_2 <= 8'd0;
                    word_3 <= 8'd0;
                end
            endcase
        end
    end
endmodule