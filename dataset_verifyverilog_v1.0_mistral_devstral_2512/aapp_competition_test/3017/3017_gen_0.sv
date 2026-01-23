module Count2eSubstring(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] e,
    input wire [3:0] n_digits [0:18],
    output reg [63:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOOKUP    = 3'd1;
    localparam [2:0] INIT_DP   = 3'd2;
    localparam [2:0] PREPARE_LOOP = 3'd3;
    localparam [2:0] ITERATE   = 3'd4;
    localparam [2:0] SUM       = 3'd5;

    reg [2:0] state, next_state;

    // ROM for 2^e decimal strings (precomputed for e=0 to 63)
    // Format: {valid, length, digit0, digit1, ... digit7}
    // Each digit is 4-bit BCD, length is 3-bit (max 8 digits)
    reg [35:0] pow2_rom [0:63];
    reg [2:0] m;  // Length of pattern
    reg [3:0] pattern [0:7];  // Pattern digits (BCD)
    reg pattern_valid;

    // KMP automaton
    reg [3:0] kmp_table [0:7][0:9];  // [state][digit] -> next_state

    // DP state
    reg [63:0] current_dp [0:1][0:1][0:7];  // [tight][started][state]
    reg [63:0] next_dp [0:1][0:1][0:7];

    // Loop control
    reg [4:0] digit_pos;  // 0 to 18
    reg [3:0] current_digit;
    reg [3:0] d;

    // Temporary variables
    reg [3:0] tight_next;
    reg [3:0] started_next;
    reg [3:0] state_next;
    reg [3:0] max_digit;

    // Initialize ROM (simplified - in real design this would be precomputed)
    initial begin
        // Example entries (truncated for brevity)
        pow2_rom[0] = {1'b1, 3'd1, 4'd1, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
        pow2_rom[1] = {1'b1, 3'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
        pow2_rom[2] = {1'b1, 3'd1, 4'd4, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
        pow2_rom[3] = {1'b1, 3'd1, 4'd8, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
        pow2_rom[4] = {1'b1, 3'd2, 4'd1, 4'd6, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0};
        // ... other entries would be initialized here
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 64'd0;
            done <= 1'b0;
            digit_pos <= 5'd0;
            pattern_valid <= 1'b0;
            m <= 3'd0;
            // Initialize DP arrays
            integer i, j, k;
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    for (k = 0; k < 8; k = k + 1) begin
                        current_dp[i][j][k] <= 64'd0;
                        next_dp[i][j][k] <= 64'd0;
                    end
                end
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOOKUP;
                end
            end

            LOOKUP: begin
                next_state = INIT_DP;
            end

            INIT_DP: begin
                next_state = PREPARE_LOOP;
            end

            PREPARE_LOOP: begin
                if (digit_pos == 5'd19) begin
                    next_state = SUM;
                end else begin
                    next_state = ITERATE;
                end
            end

            ITERATE: begin
                next_state = PREPARE_LOOP;
            end

            SUM: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // LOOKUP state: Get pattern from ROM
    always @(posedge clk) begin
        if (state == LOOKUP) begin
            reg [35:0] rom_entry = pow2_rom[e];
            pattern_valid <= rom_entry[35];
            m <= rom_entry[34:32];
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                pattern[i] <= rom_entry[31 - 4*i:28 - 4*i];
            end
        end
    end

    // KMP table computation (simplified - in real design this would be precomputed)
    always @(posedge clk) begin
        if (state == LOOKUP && pattern_valid) begin
            // Initialize KMP table
            integer s, digit;
            for (s = 0; s < 8; s = s + 1) begin
                for (digit = 0; digit < 10; digit = digit + 1) begin
                    if (s < m) begin
                        if (digit == pattern[s]) begin
                            kmp_table[s][digit] <= s + 1'b1;
                        end else begin
                            // Compute failure function (simplified)
                            kmp_table[s][digit] <= 3'd0;
                        end
                    end else begin
                        kmp_table[s][digit] <= s;
                    end
                end
            end
        end
    end

    // INIT_DP state: Initialize DP table
    always @(posedge clk) begin
        if (state == INIT_DP) begin
            // Initialize DP[0][0][0] = 1 (empty string)
            current_dp[0][0][0] <= 64'd1;
            // All other states = 0
            integer i, j, k;
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    for (k = 0; k < 8; k = k + 1) begin
                        if (!(i == 0 && j == 0 && k == 0)) begin
                            current_dp[i][j][k] <= 64'd0;
                        end
                    end
                end
            end
        end
    end

    // ITERATE state: Process each digit position
    always @(posedge clk) begin
        if (state == ITERATE) begin
            // Reset next_dp
            integer i, j, k;
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    for (k = 0; k < 8; k = k + 1) begin
                        next_dp[i][j][k] <= 64'd0;
                    end
                end
            end

            // Get current digit constraint
            current_digit <= n_digits[digit_pos];

            // Process all current states
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    for (k = 0; k < 8; k = k + 1) begin
                        if (current_dp[i][j][k] != 64'd0) begin
                            // Determine digit range
                            if (i == 1'b1) begin
                                max_digit <= current_digit;
                            end else begin
                                max_digit <= 4'd9;
                            end

                            // Try all possible digits
                            for (d = 0; d <= max_digit; d = d + 1) begin
                                // Update tight
                                if (i == 1'b1 && d == current_digit) begin
                                    tight_next <= 1'b1;
                                end else begin
                                    tight_next <= 1'b0;
                                end

                                // Update started
                                if (j == 1'b1 || d != 4'd0) begin
                                    started_next <= 1'b1;
                                end else begin
                                    started_next <= 1'b0;
                                end

                                // Update KMP state
                                if (started_next == 1'b1) begin
                                    state_next <= kmp_table[k][d];
                                end else begin
                                    state_next <= 3'd0;
                                end

                                // Accumulate to next_dp
                                next_dp[tight_next][started_next][state_next] <= 
                                    next_dp[tight_next][started_next][state_next] + 
                                    current_dp[i][j][k];
                            end
                        end
                    end
                end
            end

            // Copy next_dp to current_dp
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    for (k = 0; k < 8; k = k + 1) begin
                        current_dp[i][j][k] <= next_dp[i][j][k];
                    end
                end
            end

            // Increment digit position
            digit_pos <= digit_pos + 5'd1;
        end
    end

    // SUM state: Sum all valid counts
    always @(posedge clk) begin
        if (state == SUM) begin
            reg [63:0] total = 64'd0;
            integer i, j;
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    total <= total + current_dp[i][j][m];
                end
            end
            count <= total;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule