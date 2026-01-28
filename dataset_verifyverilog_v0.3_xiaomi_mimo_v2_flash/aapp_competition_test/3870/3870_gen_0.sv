module card_game (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] m,
    input [15:0] jiro_strength [0:99],
    input [99:0] jiro_type,
    input [15:0] ciel_strength [0:99],
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] READ_JIRO = 4'd1;
localparam [3:0] READ_CIEL = 4'd2;
localparam [3:0] SORT_DEF = 4'd3;
localparam [3:0] SORT_ATK = 4'd4;
localparam [3:0] SORT_CIEL = 4'd5;
localparam [3:0] COMPUTE_TOTAL_CIEL = 4'd6;
localparam [3:0] POSS1_DEF = 4'd7;
localparam [3:0] POSS1_ATK = 4'd8;
localparam [3:0] POSS2 = 4'd9;
localparam [3:0] COMPUTE_DAMAGE1 = 4'd10;
localparam [3:0] COMPUTE_RESULT = 4'd11;
localparam [3:0] DONE = 4'd12;

reg [3:0] state, next_state;
reg [7:0] i, j, k;
reg [7:0] num_def, num_atk;
reg [15:0] def_list [0:99];
reg [15:0] atk_list [0:99];
reg [15:0] ciel_sorted [0:99];
reg [99:0] used;
reg [15:0] total_ciel;
reg [15:0] sum_def_used;
reg [15:0] damage1, damage2;
reg [15:0] temp;
reg [15:0] sum_c, sum_a;
reg [7:0] k_val; // for POSS2 loop
reg found;
reg [2:0] compute_phase; // for COMPUTE_DAMAGE1 and COMPUTE_RESULT

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        i <= 8'd0;
        j <= 8'd0;
        k <= 8'd0;
        num_def <= 8'd0;
        num_atk <= 8'd0;
        total_ciel <= 16'd0;
        sum_def_used <= 16'd0;
        damage1 <= 16'd0;
        damage2 <= 16'd0;
        sum_c <= 16'd0;
        sum_a <= 16'd0;
        used <= 100'd0;
        k_val <= 8'd0;
        compute_phase <= 3'd0;
        temp <= 16'd0;
        found <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= READ_JIRO;
                    i <= 8'd0;
                    num_def <= 8'd0;
                    num_atk <= 8'd0;
                end
            end

            READ_JIRO: begin
                if (i < n) begin
                    if (jiro_type[i] == 1'b0) begin
                        def_list[num_def] <= jiro_strength[i];
                        num_def <= num_def + 1;
                    end else begin
                        atk_list[num_atk] <= jiro_strength[i];
                        num_atk <= num_atk + 1;
                    end
                    i <= i + 8'd1;
                end else begin
                    i <= 8'd0;
                    state <= READ_CIEL;
                end
            end

            READ_CIEL: begin
                if (i < m) begin
                    ciel_sorted[i] <= ciel_strength[i];
                    i <= i + 8'd1;
                end else begin
                    i <= 8'd0;
                    j <= 8'd0;
                    state <= SORT_DEF;
                end
            end

            SORT_DEF: begin
                if (num_def > 8'd1) begin
                    if (i < num_def - 1) begin
                        if (j < num_def - 1 - i) begin
                            if (def_list[j] > def_list[j+1]) begin
                                temp <= def_list[j];
                                def_list[j] <= def_list[j+1];
                                def_list[j+1] <= temp;
                            end
                            j <= j + 8'd1;
                        end else begin
                            j <= 8'd0;
                            i <= i + 8'd1;
                        end
                    end else begin
                        i <= 8'd0;
                        j <= 8'd0;
                        state <= SORT_ATK;
                    end
                end else begin
                    i <= 8'd0;
                    j <= 8'd0;
                    state <= SORT_ATK;
                end
            end

            SORT_ATK: begin
                if (num_atk > 8'd1) begin
                    if (i < num_atk - 1) begin
                        if (j < num_atk - 1 - i) begin
                            if (atk_list[j] > atk_list[j+1]) begin
                                temp <= atk_list[j];
                                atk_list[j] <= atk_list[j+1];
                                atk_list[j+1] <= temp;
                            end
                            j <= j + 8'd1;
                        end else begin
                            j <= 8'd0;
                            i <= i + 8'd1;
                        end
                    end else begin
                        i <= 8'd0;
                        j <= 8'd0;
                        state <= SORT_CIEL;
                    end
                end else begin
                    i <= 8'd0;
                    j <= 8'd0;
                    state <= SORT_CIEL;
                end
            end

            SORT_CIEL: begin
                if (m > 8'd1) begin
                    if (i < m - 1) begin
                        if (j < m - 1 - i) begin
                            if (ciel_sorted[j] > ciel_sorted[j+1]) begin
                                temp <= ciel_sorted[j];
                                ciel_sorted[j] <= ciel_sorted[j+1];
                                ciel_sorted[j+1] <= temp;
                            end
                            j <= j + 8'd1;
                        end else begin
                            j <= 8'd0;
                            i <= i + 8'd1;
                        end
                    end else begin
                        i <= 8'd0;
                        total_ciel <= 16'd0;
                        state <= COMPUTE_TOTAL_CIEL;
                    end
                end else begin
                    i <= 8'd0;
                    total_ciel <= 16'd0;
                    state <= COMPUTE_TOTAL_CIEL;
                end
            end

            COMPUTE_TOTAL_CIEL: begin
                if (i < m) begin
                    total_ciel <= total_ciel + ciel_sorted[i];
                    i <= i + 8'd1;
                end else begin
                    i <= 8'd0;
                    j <= 8'd0;
                    used <= 100'd0;
                    sum_def_used <= 16'd0;
                    found <= 1'b0;
                    state <= POSS1_DEF;
                end
            end

            POSS1_DEF: begin
                if (i < num_def) begin
                    if (j < m) begin
                        if (!used[j] && ciel_sorted[j] > def_list[i]) begin
                            used[j] <= 1'b1;
                            sum_def_used <= sum_def_used + ciel_sorted[j];
                            found <= 1'b1;
                        end
                        j <= j + 8'd1;
                    end else begin
                        if (!found) begin
                            damage1 <= 16'd0;
                            state <= POSS2;
                            i <= 8'd0;
                            sum_c <= 16'd0;
                            sum_a <= 16'd0;
                            k_val <= 8'd0;
                            damage2 <= 16'd0;
                        end else begin
                            i <= i + 8'd1;
                            j <= 8'd0;
                            found <= 1'b0;
                        end
                    end
                end else begin
                    i <= 8'd0;
                    temp <= 16'd0;
                    state <= POSS1_ATK;
                end
            end

            POSS1_ATK: begin
                if (i < num_atk) begin
                    if (j < m) begin
                        if (!used[j] && ciel_sorted[j] >= atk_list[i]) begin
                            used[j] <= 1'b1;
                            found <= 1'b1;
                        end
                        j <= j + 8'd1;
                    end else begin
                        if (!found) begin
                            damage1 <= 16'd0;
                            state <= POSS2;
                            i <= 8'd0;
                            sum_c <= 16'd0;
                            sum_a <= 16'd0;
                            k_val <= 8'd0;
                            damage2 <= 16'd0;
                        end else begin
                            i <= i + 8'd1;
                            j <= 8'd0;
                            found <= 1'b0;
                        end
                    end
                end else begin
                    state <= COMPUTE_DAMAGE1;
                    compute_phase <= 3'd0;
                    temp <= 16'd0;
                    i <= 8'd0;
                end
            end

            POSS2: begin
                // damage2 = max over k where sum of largest k Ciel >= sum of smallest k ATK
                // Using largest k Ciel cards: ciel_sorted[m-1], ciel_sorted[m-2], ...
                // Using smallest k ATK cards: atk_list[0], atk_list[1], ...
                if (k_val < num_atk && k_val < m) begin
                    // Check if the (k_val)th largest Ciel card >= (k_val)th smallest ATK card
                    // Indices: Ciel index = m - 1 - k_val, ATK index = k_val
                    if (ciel_sorted[m - 1 - k_val] >= atk_list[k_val]) begin
                        sum_c <= sum_c + ciel_sorted[m - 1 - k_val];
                        sum_a <= sum_a + atk_list[k_val];
                        // Compute damage for this k = k_val + 1
                        if (sum_c + ciel_sorted[m - 1 - k_val] > sum_a + atk_list[k_val]) begin
                            damage2 <= (sum_c + ciel_sorted[m - 1 - k_val]) - (sum_a + atk_list[k_val]);
                        end
                        k_val <= k_val + 8'd1;
                    end else begin
                        state <= COMPUTE_DAMAGE1;
                        compute_phase <= 3'd0;
                        temp <= 16'd0;
                        i <= 8'd0;
                    end
                end else begin
                    state <= COMPUTE_DAMAGE1;
                    compute_phase <= 3'd0;
                    temp <= 16'd0;
                    i <= 8'd0;
                end
            end

            COMPUTE_DAMAGE1: begin
                // damage1 = total_ciel - sum_def_used - sum(atk_list)
                case (compute_phase)
                    3'd0: begin
                        temp <= 16'd0;
                        i <= 8'd0;
                        compute_phase <= 3'd1;
                    end
                    3'd1: begin
                        if (i < num_atk) begin
                            temp <= temp + atk_list[i];
                            i <= i + 8'd1;
                        end else begin
                            damage1 <= total_ciel - sum_def_used - temp;
                            compute_phase <= 3'd2;
                        end
                    end
                    3'd2: begin
                        state <= COMPUTE_RESULT;
                        compute_phase <= 3'd0;
                    end
                    default: compute_phase <= 3'd0;
                endcase
            end

            COMPUTE_RESULT: begin
                if (damage1 > damage2) begin
                    result <= damage1;
                end else begin
                    result <= damage2;
                end
                state <= DONE;
            end

            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule