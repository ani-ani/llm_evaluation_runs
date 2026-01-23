module cfg_search (
    input clk,
    input rst_n,
    input start,
    input [4:0] rule_count,
    input [5:0][39:0] rule_data,
    input [127:0] text_data,
    output reg [7:0] result_start,
    output reg [7:0] result_length,
    output reg [127:0] result_substr,
    output reg done
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        PARSE_RULES,
        PROCESSING,
        DONE
    } state_t;
    state_t state = IDLE;

    // Internal storage
    logic [7:0] grammar [26][3]; // A-Z, 3 possible productions per variable
    logic [7:0] text [16];
    logic [25:0] dp_table [16][16]; // dp_table[i][j] = variables that can generate text[i..i+j-1]
    logic [7:0] max_start = 0;
    logic [7:0] max_length = 0;
    logic [127:0] max_substr = 0;

    // Counters
    logic [3:0] rule_idx = 0;
    logic [3:0] i = 0;
    logic [3:0] j = 0;
    logic [3:0] k = 0;
    logic [3:0] rule_pos = 0;
    logic [3:0] prod_len = 0;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rule_idx <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            rule_pos <= 0;
            prod_len <= 0;
            max_start <= 0;
            max_length <= 0;
            max_substr <= 0;
            done <= 0;
            result_start <= 0;
            result_length <= 0;
            result_substr <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE_RULES;
                        rule_idx <= 0;
                        // Initialize grammar storage
                        for (int v = 0; v < 26; v++) begin
                            for (int p = 0; p < 3; p++) begin
                                grammar[v][p] <= 0;
                            end
                        end
                    end
                end

                PARSE_RULES: begin
                    if (rule_idx < rule_count) begin
                        logic [7:0] head = rule_data[rule_idx][39:32];
                        logic [7:0] len = rule_data[rule_idx][31:24];
                        logic [23:0] prod = rule_data[rule_idx][23:0];
                        logic [4:0] var_idx = head - 8'h41; // 'A' = 0

                        // Store production
                        for (int p = 0; p < 3; p++) begin
                            if (grammar[var_idx][p] == 0) begin
                                grammar[var_idx][p] = {len, prod};
                                break;
                            end
                        end
                        rule_idx <= rule_idx + 1;
                    end else begin
                        // Parse text
                        for (int t = 0; t < 16; t++) begin
                            text[t] = text_data[t*8 +: 8];
                        end
                        state <= PROCESSING;
                        i <= 0;
                        j <= 0;
                        k <= 0;
                    end
                end

                PROCESSING: begin
                    // Initialize DP table
                    if (i == 0 && j == 0 && k == 0) begin
                        for (int x = 0; x < 16; x++) begin
                            for (int y = 0; y < 16; y++) begin
                                dp_table[x][y] <= 0;
                            end
                        end
                        i <= 0;
                        j <= 1;
                    end

                    // Fill DP table
                    if (j <= 16) begin
                        if (i + j <= 16) begin
                            // Check all rules for this substring
                            for (int v = 0; v < 26; v++) begin
                                for (int p = 0; p < 3; p++) begin
                                    logic [23:0] prod = grammar[v][p][23:0];
                                    logic [7:0] len = grammar[v][p][31:24];

                                    if (len == 0) begin
                                        // Empty production
                                        dp_table[i][j][v] <= 1'b1;
                                    end else if (len == 1) begin
                                        // Terminal production
                                        if (text[i] == prod[7:0]) begin
                                            dp_table[i][j][v] <= 1'b1;
                                        end
                                    end else if (len == 2) begin
                                        // Binary production
                                        for (int split = 1; split < j; split++) begin
                                            logic [7:0] left_var = prod[7:0];
                                            logic [7:0] right_var = prod[15:8];
                                            if (dp_table[i][split][left_var - 8'h41] && 
                                                dp_table[i+split][j-split][right_var - 8'h41]) begin
                                                dp_table[i][j][v] <= 1'b1;
                                            end
                                        end
                                    end else if (len == 3) begin
                                        // Ternary production
                                        for (int split1 = 1; split1 < j-1; split1++) begin
                                            for (int split2 = split1+1; split2 < j; split2++) begin
                                                logic [7:0] var1 = prod[7:0];
                                                logic [7:0] var2 = prod[15:8];
                                                logic [7:0] var3 = prod[23:16];
                                                if (dp_table[i][split1][var1 - 8'h41] && 
                                                    dp_table[i+split1][split2-split1][var2 - 8'h41] &&
                                                    dp_table[i+split2][j-split2][var3 - 8'h41]) begin
                                                    dp_table[i][j][v] <= 1'b1;
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            // Check if start symbol (S) can generate this substring
                            if (dp_table[i][j][18] && j > max_length) begin // 'S' = 18
                                max_length <= j;
                                max_start <= i;
                                // Store substring
                                for (int pos = 0; pos < 16; pos++) begin
                                    if (pos < j) begin
                                        max_substr[pos*8 +: 8] <= text[i + pos];
                                    end else begin
                                        max_substr[pos*8 +: 8] <= 0;
                                    end
                                end
                            end

                            // Move to next position
                            i <= i + 1;
                            if (i + j >= 16) begin
                                i <= 0;
                                j <= j + 1;
                            end
                        end else begin
                            i <= 0;
                            j <= j + 1;
                        end
                    end else begin
                        state <= DONE;
                        done <= 1;
                        result_start <= max_start;
                        result_length <= max_length;
                        result_substr <= max_substr;
                    end
                end
            end

            DONE: begin
                if (!start) begin
                    state <= IDLE;
                    done <= 0;
                end
            end
        end
    end

endmodule