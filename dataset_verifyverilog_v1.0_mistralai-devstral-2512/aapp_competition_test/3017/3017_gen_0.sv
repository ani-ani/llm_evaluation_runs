module SubstringCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_digits [0:18],
    input wire [4:0] n_len,
    input wire [3:0] pattern_digits [0:18],
    input wire [4:0] p_len,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_LPS = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_LOOP = 3'd3;
    localparam [2:0] AGGREGATE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;

    // LPS array for KMP
    reg [4:0] lps [0:18];
    reg [4:0] lps_index;
    reg [4:0] lps_len;

    // Pattern storage
    reg [3:0] pattern [0:18];

    // DP state variables
    reg [4:0] pos;
    reg [4:0] tight;
    reg [4:0] started;
    reg [4:0] match_len;
    reg [4:0] found;

    // DP count buffers
    reg [63:0] dp_cur [0:1][0:1][0:19][0:1];
    reg [63:0] dp_next [0:1][0:1][0:19][0:1];

    // Loop counters
    reg [4:0] tight_iter;
    reg [4:0] started_iter;
    reg [4:0] match_len_iter;
    reg [4:0] found_iter;
    reg [3:0] digit_iter;

    // Temporary variables
    reg [3:0] current_digit;
    reg [4:0] new_match_len;
    reg [63:0] temp_count;

    // Cycle counter for safety
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            cycle_count <= 14'd0;

            // Initialize LPS array
            lps_index <= 5'd0;
            lps_len <= 5'd0;

            // Initialize DP arrays
            for (tight_iter = 0; tight_iter < 2; tight_iter = tight_iter + 1) begin
                for (started_iter = 0; started_iter < 2; started_iter = started_iter + 1) begin
                    for (match_len_iter = 0; match_len_iter < 20; match_len_iter = match_len_iter + 1) begin
                        for (found_iter = 0; found_iter < 2; found_iter = found_iter + 1) begin
                            dp_cur[tight_iter][started_iter][match_len_iter][found_iter] <= 64'd0;
                            dp_next[tight_iter][started_iter][match_len_iter][found_iter] <= 64'd0;
                        end
                    end
                end
            end

            // Initialize loop counters
            pos <= 5'd0;
            tight <= 5'd0;
            started <= 5'd0;
            match_len <= 5'd0;
            found <= 5'd0;
            tight_iter <= 5'd0;
            started_iter <= 5'd0;
            match_len_iter <= 5'd0;
            found_iter <= 5'd0;
            digit_iter <= 4'd0;
            current_digit <= 4'd0;
            new_match_len <= 5'd0;
            temp_count <= 64'd0;

            // Initialize pattern
            for (lps_index = 0; lps_index < 19; lps_index = lps_index + 1) begin
                pattern[lps_index] <= pattern_digits[lps_index];
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 14'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COMPUTE_LPS;
                        cycle_count <= 14'd0;
                    end
                end

                COMPUTE_LPS: begin
                    // Compute LPS array for KMP
                    if (lps_index == 0) begin
                        lps[0] <= 5'd0;
                        lps_len <= 5'd0;
                        lps_index <= 5'd1;
                    end else if (lps_index < p_len) begin
                        if (pattern[lps_index] == pattern[lps_len]) begin
                            lps_len <= lps_len + 5'd1;
                            lps[lps_index] <= lps_len;
                            lps_index <= lps_index + 5'd1;
                        end else begin
                            if (lps_len != 5'd0) begin
                                lps_len <= lps[lps_len - 5'd1];
                            end else begin
                                lps[lps_index] <= 5'd0;
                                lps_index <= lps_index + 5'd1;
                            end
                        end
                    end else begin
                        next_state <= DP_INIT;
                        lps_index <= 5'd0;
                        lps_len <= 5'd0;
                    end
                end

                DP_INIT: begin
                    // Initialize DP state
                    dp_cur[1][0][0][0] <= 64'd1;  // tight=1, started=0, match_len=0, found=0
                    pos <= 5'd0;
                    next_state <= DP_LOOP;
                end

                DP_LOOP: begin
                    if (pos < n_len) begin
                        // Clear next DP buffer
                        for (tight_iter = 0; tight_iter < 2; tight_iter = tight_iter + 1) begin
                            for (started_iter = 0; started_iter < 2; started_iter = started_iter + 1) begin
                                for (match_len_iter = 0; match_len_iter < 20; match_len_iter = match_len_iter + 1) begin
                                    for (found_iter = 0; found_iter < 2; found_iter = found_iter + 1) begin
                                        dp_next[tight_iter][started_iter][match_len_iter][found_iter] <= 64'd0;
                                    end
                                end
                            end
                        end

                        // Iterate through all previous states
                        for (tight_iter = 0; tight_iter < 2; tight_iter = tight_iter + 1) begin
                            for (started_iter = 0; started_iter < 2; started_iter = started_iter + 1) begin
                                for (match_len_iter = 0; match_len_iter < 20; match_len_iter = match_len_iter + 1) begin
                                    for (found_iter = 0; found_iter < 2; found_iter = found_iter + 1) begin
                                        temp_count <= dp_cur[tight_iter][started_iter][match_len_iter][found_iter];
                                        if (temp_count != 64'd0) begin
                                            // Determine digit range
                                            if (tight_iter == 1) begin
                                                for (digit_iter = 0; digit_iter <= n_digits[pos]; digit_iter = digit_iter + 1) begin
                                                    current_digit <= digit_iter;
                                                    // Compute new tight
                                                    tight <= tight_iter & (digit_iter == n_digits[pos]);
                                                    // Compute new started
                                                    started <= started_iter | (digit_iter != 4'd0);
                                                    // Compute new match_len using KMP
                                                    if (started == 1) begin
                                                        if (digit_iter == pattern[match_len_iter]) begin
                                                            new_match_len <= match_len_iter + 5'd1;
                                                        end else begin
                                                            if (match_len_iter != 5'd0) begin
                                                                new_match_len <= lps[match_len_iter - 5'd1];
                                                            end else begin
                                                                new_match_len <= 5'd0;
                                                            end
                                                            if (digit_iter == pattern[new_match_len]) begin
                                                                new_match_len <= new_match_len + 5'd1;
                                                            end
                                                        end
                                                    end else begin
                                                        new_match_len <= 5'd0;
                                                    end
                                                    // Compute new found
                                                    found <= found_iter | (new_match_len == p_len);
                                                    // Accumulate count
                                                    dp_next[tight][started][new_match_len][found] <= dp_next[tight][started][new_match_len][found] + temp_count;
                                                end
                                            end else begin
                                                for (digit_iter = 0; digit_iter < 10; digit_iter = digit_iter + 1) begin
                                                    current_digit <= digit_iter;
                                                    tight <= 5'd0;
                                                    started <= started_iter | (digit_iter != 4'd0);
                                                    if (started == 1) begin
                                                        if (digit_iter == pattern[match_len_iter]) begin
                                                            new_match_len <= match_len_iter + 5'd1;
                                                        end else begin
                                                            if (match_len_iter != 5'd0) begin
                                                                new_match_len <= lps[match_len_iter - 5'd1];
                                                            end else begin
                                                                new_match_len <= 5'd0;
                                                            end
                                                            if (digit_iter == pattern[new_match_len]) begin
                                                                new_match_len <= new_match_len + 5'd1;
                                                            end
                                                        end
                                                    end else begin
                                                        new_match_len <= 5'd0;
                                                    end
                                                    found <= found_iter | (new_match_len == p_len);
                                                    dp_next[tight][started][new_match_len][found] <= dp_next[tight][started][new_match_len][found] + temp_count;
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        // Swap buffers
                        for (tight_iter = 0; tight_iter < 2; tight_iter = tight_iter + 1) begin
                            for (started_iter = 0; started_iter < 2; started_iter = started_iter + 1) begin
                                for (match_len_iter = 0; match_len_iter < 20; match_len_iter = match_len_iter + 1) begin
                                    for (found_iter = 0; found_iter < 2; found_iter = found_iter + 1) begin
                                        dp_cur[tight_iter][started_iter][match_len_iter][found_iter] <= dp_next[tight_iter][started_iter][match_len_iter][found_iter];
                                    end
                                end
                            end
                        end

                        pos <= pos + 5'd1;
                    end else begin
                        next_state <= AGGREGATE;
                        pos <= 5'd0;
                    end
                end

                AGGREGATE: begin
                    result <= 64'd0;
                    for (tight_iter = 0; tight_iter < 2; tight_iter = tight_iter + 1) begin
                        for (started_iter = 0; started_iter < 2; started_iter = started_iter + 1) begin
                            for (match_len_iter = 0; match_len_iter < 20; match_len_iter = match_len_iter + 1) begin
                                result <= result + dp_cur[tight_iter][started_iter][match_len_iter][1];
                            end
                        end
                    end
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Safety check for max cycles
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule