module card_battle_damage(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] jiro_pos,
    input wire [12:0] jiro_str [0:15],
    input wire [12:0] ciel_str [0:15],
    input wire [3:0] n,
    input wire [3:0] m,
    output reg [23:0] result,
    output reg done
);

// State definitions
localparam [5:0] IDLE          = 6'd0;
localparam [5:0] PARSE_INIT    = 6'd1;
localparam [5:0] PARSE_LOOP    = 6'd2;
localparam [5:0] SORT_DEF       = 6'd3;
localparam [5:0] SORT_ATK       = 6'd4;
localparam [5:0] SORT_CIEL      = 6'd5;
localparam [5:0] STRAT1_MATCH   = 6'd6;
localparam [5:0] STRAT1_CALC    = 6'd7;
localparam [5:0] STRAT1_DIRECT  = 6'd8;
localparam [5:0] STRAT2_SETUP   = 6'd9;
localparam [5:0] STRAT2_SORT    = 6'd10;
localparam [5:0] STRAT2_MATCH   = 6'd11;
localparam [5:0] SELECT_RESULT  = 6'd12;
localparam [5:0] FINISH         = 6'd13;

reg [5:0] state, next_state;

// Internal registers
reg [15:0] def_str_reg [0:15];
reg [15:0] atk_str_reg [0:15];
reg [15:0] ciel_str_reg [0:15];
reg [3:0] def_cnt;
reg [3:0] atk_cnt;
reg [3:0] ciel_cnt;

// Strategy 1 registers
reg [23:0] strat1_damage;
reg [3:0] ciel_used_cnt;
reg [15:0] remaining_ciel [0:15];
reg [3:0] remaining_cnt;
reg strat1_valid;

// Strategy 2 registers
reg [23:0] strat2_damage;

// Sorting/Matching variables
reg [3:0] i, j, k;
reg [15:0] temp;
reg [3:0] match_idx;
reg [23:0] damage_sum;
reg [15:0] matched_ciel [0:15];
reg [3:0] matched_cnt;
reg [15:0] temp_ciel [0:15];

// Combinatorial signals for comparison
reg cmp_result;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 24'd0;
        done <= 1'b0;
        def_cnt <= 4'd0;
        atk_cnt <= 4'd0;
        ciel_cnt <= 4'd0;
        strat1_damage <= 24'd0;
        strat2_damage <= 24'd0;
        strat1_valid <= 1'b0;
        i <= 4'd0;
        j <= 4'd0;
        k <= 4'd0;
        match_idx <= 4'd0;
        damage_sum <= 24'd0;
        ciel_used_cnt <= 4'd0;
        remaining_cnt <= 4'd0;
        matched_cnt <= 4'd0;
        // Initialize arrays
        for (int init_i = 0; init_i < 16; init_i = init_i + 1) begin
            def_str_reg[init_i] <= 16'd0;
            atk_str_reg[init_i] <= 16'd0;
            ciel_str_reg[init_i] <= 16'd0;
            remaining_ciel[init_i] <= 16'd0;
            matched_ciel[init_i] <= 16'd0;
            temp_ciel[init_i] <= 16'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PARSE_INIT;
                end
            end

            // Parse inputs
            PARSE_INIT: begin
                def_cnt <= 4'd0;
                atk_cnt <= 4'd0;
                i <= 4'd0;
                state <= PARSE_LOOP;
            end

            PARSE_LOOP: begin
                if (i < n) begin
                    if (jiro_pos[i]) begin
                        // Attack card
                        atk_str_reg[atk_cnt] <= {3'd0, jiro_str[i]};
                        atk_cnt <= atk_cnt + 4'd1;
                    end else begin
                        // Defense card
                        def_str_reg[def_cnt] <= {3'd0, jiro_str[i]};
                        def_cnt <= def_cnt + 4'd1;
                    end
                    ciel_str_reg[i] <= {3'd0, ciel_str[i]};
                    i <= i + 4'd1;
                end else begin
                    // Fill remaining Ciel cards
                    if (i < m) begin
                        ciel_str_reg[i] <= {3'd0, ciel_str[i]};
                        i <= i + 4'd1;
                    end else begin
                        ciel_cnt <= m;
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= SORT_DEF;
                    end
                end
            end

            // Bubble Sort Def cards ascending
            SORT_DEF: begin
                if (i < def_cnt) begin
                    if (j < def_cnt - 4'd1) begin
                        if (def_str_reg[j] > def_str_reg[j+1]) begin
                            temp <= def_str_reg[j];
                            def_str_reg[j] <= def_str_reg[j+1];
                            def_str_reg[j+1] <= temp;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                    end
                end else begin
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= SORT_ATK;
                end
            end

            // Bubble Sort Atk cards ascending
            SORT_ATK: begin
                if (i < atk_cnt) begin
                    if (j < atk_cnt - 4'd1) begin
                        if (atk_str_reg[j] > atk_str_reg[j+1]) begin
                            temp <= atk_str_reg[j];
                            atk_str_reg[j] <= atk_str_reg[j+1];
                            atk_str_reg[j+1] <= temp;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                    end
                end else begin
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= SORT_CIEL;
                end
            end

            // Bubble Sort Ciel cards ascending
            SORT_CIEL: begin
                if (i < ciel_cnt) begin
                    if (j < ciel_cnt - 4'd1) begin
                        if (ciel_str_reg[j] > ciel_str_reg[j+1]) begin
                            temp <= ciel_str_reg[j];
                            ciel_str_reg[j] <= ciel_str_reg[j+1];
                            ciel_str_reg[j+1] <= temp;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                    end
                end else begin
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    ciel_used_cnt <= 4'd0;
                    strat1_damage <= 24'd0;
                    strat1_valid <= 1'b1;
                    state <= STRAT1_MATCH;
                end
            end

            // Strategy 1: Match Def cards
            STRAT1_MATCH: begin
                if (i < def_cnt) begin
                    // Try to match current Def card with available Ciel cards
                    if (k < ciel_cnt) begin
                        // Check if Ciel card can beat Def card (strictly greater)
                        if (ciel_str_reg[k] > def_str_reg[i]) begin
                            // Match found, mark used
                            ciel_str_reg[k] <= 16'd0; // Mark as used
                            ciel_used_cnt <= ciel_used_cnt + 4'd1;
                            i <= i + 4'd1;
                            k <= 4'd0; // Reset search
                        end else begin
                            k <= k + 4'd1;
                        end
                    end else begin
                        // No card found
                        strat1_valid <= 1'b0;
                        state <= STRAT2_SETUP;
                    end
                end else begin
                    // All Def cards matched, now collect remaining Ciel cards
                    remaining_cnt <= 4'd0;
                    k <= 4'd0;
                    state <= STRAT1_CALC;
                end
            end

            // Collect remaining Ciel cards
            STRAT1_CALC: begin
                if (k < ciel_cnt) begin
                    if (ciel_str_reg[k] != 16'd0) begin
                        remaining_ciel[remaining_cnt] <= ciel_str_reg[k];
                        remaining_cnt <= remaining_cnt + 4'd1;
                    end
                    k <= k + 4'd1;
                end else begin
                    // Sort remaining Ciel ascending
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= SORT_CIEL; // Reuse sort logic
                    // Redirect to STRAT1_DIRECT after sort
                end
            end

            // Match Atk cards with remaining Ciel
            STRAT1_DIRECT: begin
                if (i < atk_cnt) begin
                    if (j < remaining_cnt) begin
                        if (remaining_ciel[j] >= atk_str_reg[i]) begin
                            // Match found
                            strat1_damage <= strat1_damage + (remaining_ciel[j] - atk_str_reg[i]);
                            remaining_ciel[j] <= 16'd0;
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end else begin
                            j <= j + 4'd1;
                        end
                    end else begin
                        // No match found
                        strat1_valid <= 1'b0;
                        state <= STRAT2_SETUP;
                    end
                end else begin
                    // All Atk cards matched
                    // Add unused Ciel cards as direct attack
                    for (int idx = 0; idx < 16; idx = idx + 1) begin
                        if (idx < remaining_cnt && remaining_ciel[idx] != 16'd0) begin
                            strat1_damage <= strat1_damage + remaining_ciel[idx];
                        end
                    end
                    state <= STRAT2_SETUP;
                end
            end

            // Setup Strategy 2
            STRAT2_SETUP: begin
                // Copy Atk cards to temp array
                for (int idx = 0; idx < 16; idx = idx + 1) begin
                    if (idx < atk_cnt) begin
                        temp_ciel[idx] <= atk_str_reg[idx];
                    end else begin
                        temp_ciel[idx] <= 16'd0;
                    end
                end
                // Copy Ciel cards (ascending) to temp array for sorting descending
                for (int idx = 0; idx < 16; idx = idx + 1) begin
                    if (idx < ciel_cnt) begin
                        matched_ciel[idx] <= {3'd0, ciel_str[idx]}; // Reload original
                    end else begin
                        matched_ciel[idx] <= 16'd0;
                    end
                end
                strat2_damage <= 24'd0;
                i <= 4'd0;
                j <= 4'd0;
                state <= STRAT2_SORT;
            end

            // Sort Ciel descending for Strategy 2
            STRAT2_SORT: begin
                // Bubble sort matched_ciel descending
                if (i < ciel_cnt) begin
                    if (j < ciel_cnt - 4'd1) begin
                        if (matched_ciel[j] < matched_ciel[j+1]) begin
                            temp <= matched_ciel[j];
                            matched_ciel[j] <= matched_ciel[j+1];
                            matched_ciel[j+1] <= temp;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                    end
                end else begin
                    // Sort Atk ascending (already sorted from Strat1)
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= STRAT2_MATCH;
                end
            end

            // Strategy 2 Match
            STRAT2_MATCH: begin
                if (i < ciel_cnt) begin
                    if (j < atk_cnt) begin
                        if (matched_ciel[i] >= temp_ciel[j]) begin
                            strat2_damage <= strat2_damage + (matched_ciel[i] - temp_ciel[j]);
                            i <= i + 4'd1;
                            j <= j + 4'd1;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        // No more Atk cards
                        i <= ciel_cnt; // Force loop exit
                        state <= SELECT_RESULT;
                    end
                end else begin
                    state <= SELECT_RESULT;
                end
            end

            // Select Result
            SELECT_RESULT: begin
                if (strat1_valid && strat1_damage > strat2_damage) begin
                    result <= strat1_damage;
                end else begin
                    result <= strat2_damage;
                end
                state <= FINISH;
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

// Combinational logic to handle sort re-direction
always @(*) begin
    // Default next state
    next_state = state;
    
    if (state == STRAT1_CALC) begin
        // After collecting remaining cards, sort them
        next_state = STRAT1_DIRECT; // Will go to sort, then back here
    end
end

endmodule