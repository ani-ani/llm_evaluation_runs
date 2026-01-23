module loda_teleport (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_strings,
    input [7:0] strings [0:7],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] INPUT_PARSE = 3'b001;
    localparam [2:0] COMPARE = 3'b010;
    localparam [2:0] DP_CALC = 3'b011;
    localparam [2:0] RESULT = 3'b100;
    localparam [2:0] DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // String length storage (1-based)
    reg [2:0] str_len [0:7];

    // Dependency matrix: dep[i][j] = 1 if string[j] starts and ends with string[i]
    reg dep [0:7][0:7];

    // DP array
    reg [2:0] dp [0:7];

    // Counters
    reg [2:0] i, j, k;
    reg [2:0] max_len;

    // Helper registers
    reg [7:0] char_a, char_b;
    reg [2:0] len_a, len_b;
    reg prefix_match, suffix_match;
    reg [2:0] temp_max;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INPUT_PARSE;
            end
            INPUT_PARSE: begin
                if (i == num_strings) next_state = COMPARE;
            end
            COMPARE: begin
                if (i == num_strings - 1 && j == num_strings) next_state = DP_CALC;
            end
            DP_CALC: begin
                if (i == num_strings) next_state = RESULT;
            end
            RESULT: begin
                if (i == num_strings) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            for (i = 0; i < 8; i = i + 1) begin
                str_len[i] <= 0;
                for (j = 0; j < 8; j = j + 1) begin
                    dep[i][j] <= 0;
                end
                dp[i] <= 0;
            end
            i <= 0;
            j <= 0;
            k <= 0;
            max_len <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                INPUT_PARSE: begin
                    // Calculate string lengths
                    if (j == 0) begin
                        str_len[i] <= 0;
                        j <= 0;
                    end
                    // Find first null byte or end of 8 bytes
                    if (strings[i][j] != 0 && j < 7) begin
                        j <= j + 1;
                    end else begin
                        str_len[i] <= (strings[i][j] != 0) ? j + 1 : j;
                        if (i < num_strings - 1) begin
                            i <= i + 1;
                            j <= 0;
                        end else begin
                            i <= i + 1;
                        end
                    end
                end
                COMPARE: begin
                    // Initialize comparison
                    if (i == 0 && j == 0) begin
                        for (k = 0; k < 8; k = k + 1) begin
                            for (m = 0; m < 8; m = m + 1) begin
                                dep[k][m] <= 0;
                            end
                        end
                    end
                    // Compare strings i and j (i < j)
                    if (j <= i) begin
                        if (j == num_strings - 1) begin
                            i <= i + 1;
                            j <= 0;
                        end else begin
                            j <= j + 1;
                        end
                    end else begin
                        len_a = str_len[i];
                        len_b = str_len[j];
                        // Check if string[j] starts with string[i]
                        prefix_match = 1;
                        for (k = 0; k < len_a; k = k + 1) begin
                            if (strings[i][k] != strings[j][k]) begin
                                prefix_match = 0;
                            end
                        end
                        // Check if string[j] ends with string[i]
                        suffix_match = 1;
                        for (k = 0; k < len_a; k = k + 1) begin
                            if (strings[i][k] != strings[j][len_b - len_a + k]) begin
                                suffix_match = 0;
                            end
                        end
                        dep[i][j] <= prefix_match && suffix_match;
                        if (j == num_strings - 1) begin
                            i <= i + 1;
                            j <= 0;
                        end else begin
                            j <= j + 1;
                        end
                    end
                end
                DP_CALC: begin
                    // Initialize DP calculation
                    if (i == 0) begin
                        dp[i] <= 1;
                        i <= i + 1;
                    end else begin
                        temp_max = 0;
                        for (j = 0; j < i; j = j + 1) begin
                            if (dep[j][i] && dp[j] > temp_max) begin
                                temp_max = dp[j];
                            end
                        end
                        dp[i] <= temp_max + 1;
                        if (i < num_strings - 1) begin
                            i <= i + 1;
                        end
                    end
                end
                RESULT: begin
                    // Find maximum DP value
                    if (i == 0) begin
                        max_len = dp[0];
                        i <= i + 1;
                    end else begin
                        if (dp[i] > max_len) begin
                            max_len = dp[i];
                        end
                        if (i < num_strings - 1) begin
                            i <= i + 1;
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                    result <= max_len;
                end
            endcase
        end
    end

endmodule