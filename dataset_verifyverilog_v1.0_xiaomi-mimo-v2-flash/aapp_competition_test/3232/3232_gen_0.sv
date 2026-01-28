module rearrange_string (
    input clk,
    input rst_n,
    input start,
    input [127:0] str_in,
    input [3:0] N,
    output reg [127:0] str_out,
    output reg result_valid,
    output reg impossible
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] EXTRACT       = 4'd1;
    localparam [3:0] CHECK_FREQ    = 4'd2;
    localparam [3:0] PREP_ORIG     = 4'd3;
    localparam [3:0] CHECK_ORIG    = 4'd4;
    localparam [3:0] PREP_REV      = 4'd5;
    localparam [3:0] CHECK_REV     = 4'd6;
    localparam [3:0] PREP_SORT     = 4'd7;
    localparam [3:0] SORT_LOOP     = 4'd8;
    localparam [3:0] CHECK_SORT    = 4'd9;
    localparam [3:0] CHECK_SUB     = 4'd10;
    localparam [3:0] UPDATE_HASH   = 4'd11;
    localparam [3:0] RESULT_FOUND  = 4'd12;
    localparam [3:0] RESULT_FAIL   = 4'd13;
    localparam [3:0] OUTPUT_RESULT = 4'd14;
    localparam [3:0] CLEANUP       = 4'd15;

    reg [3:0] state, next_state;
    reg [7:0] buffer [0:15];       // Internal character buffer
    reg [7:0] candidate [0:15];    // Candidate buffer for checking
    reg [15:0] signature [0:15];   // Hash signatures for substrings
    reg [7:0] freq [0:255];        // Frequency count (ASCII range)
    reg [3:0] idx;                 // General index
    reg [3:0] idx2;                // Secondary index
    reg [3:0] attempts;            // Attempt counter (0-2)
    reg [7:0] char_val;            // Temporary character
    reg [15:0] hash_val;           // Computed hash
    reg hash_valid;                // Hash calculation done
    reg collision_found;           // Check for hash collisions
    reg [7:0] max_freq;            // Track maximum frequency
    reg [15:0] cycle_count;        // Cycle counter for timeout
    localparam [15:0] MAX_CYCLES = 16'd1000;

    integer i, j;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            str_out <= 128'h0;
            result_valid <= 1'b0;
            impossible <= 1'b0;
            idx <= 4'd0;
            idx2 <= 4'd0;
            attempts <= 3'd0;
            cycle_count <= 16'd0;
            max_freq <= 8'd0;
            collision_found <= 1'b0;
            hash_val <= 16'd0;
            hash_valid <= 1'b0;
            char_val <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                buffer[i] <= 8'd0;
                candidate[i] <= 8'd0;
                signature[i] <= 16'd0;
            end
            for (i = 0; i < 256; i = i + 1) begin
                freq[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= EXTRACT;
                        idx <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                EXTRACT: begin
                    // Extract N characters from str_in
                    if (idx < N) begin
                        buffer[idx] <= str_in[(idx * 8) +: 8];
                        idx <= idx + 4'd1;
                        next_state <= EXTRACT;
                    end else begin
                        idx <= 4'd0;
                        next_state <= CHECK_FREQ;
                    end
                end

                CHECK_FREQ: begin
                    // Check frequency of characters
                    if (idx < N) begin
                        char_val <= buffer[idx];
                        idx <= idx + 4'd1;
                        next_state <= CHECK_FREQ;
                    end else begin
                        idx <= 4'd0;
                        attempts <= 3'd0;
                        // Check max frequency condition
                        if (max_freq > (N >> 1) + 1) begin
                            next_state <= RESULT_FAIL;
                        end else begin
                            next_state <= PREP_ORIG;
                        end
                    end
                end

                PREP_ORIG: begin
                    // Prepare original string as candidate
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < N) candidate[i] <= buffer[i];
                        else candidate[i] <= 8'd0;
                    end
                    attempts <= attempts + 3'd1;
                    idx <= 4'd0;
                    idx2 <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        signature[i] <= 16'd0;
                    end
                    next_state <= CHECK_SUB;
                end

                CHECK_SUB: begin
                    // Check all substrings of length N/2 for uniqueness
                    if (idx <= (N >> 1)) begin
                        // Compute hash for substring starting at idx
                        hash_val <= 16'd0;
                        idx2 <= 4'd0;
                        hash_valid <= 1'b0;
                        next_state <= UPDATE_HASH;
                    end else begin
                        // All substrings checked
                        if (!collision_found) begin
                            next_state <= RESULT_FOUND;
                        end else begin
                            // Try next attempt
                            if (attempts == 3'd1) next_state <= PREP_REV;
                            else if (attempts == 3'd2) next_state <= PREP_SORT;
                            else next_state <= RESULT_FAIL;
                        end
                    end
                end

                UPDATE_HASH: begin
                    // Compute hash for current substring
                    if (idx2 < (N >> 1)) begin
                        hash_val <= hash_val + {8'd0, candidate[idx + idx2]};
                        idx2 <= idx2 + 4'd1;
                        next_state <= UPDATE_HASH;
                    end else begin
                        // Check for collision
                        collision_found <= 1'b0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < idx && signature[i] == hash_val) begin
                                collision_found <= 1'b1;
                            end
                        end
                        signature[idx] <= hash_val;
                        idx <= idx + 4'd1;
                        next_state <= CHECK_SUB;
                    end
                end

                PREP_REV: begin
                    // Reverse buffer into candidate
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < N) candidate[i] <= buffer[N - 1 - i];
                        else candidate[i] <= 8'd0;
                    end
                    attempts <= attempts + 3'd1;
                    idx <= 4'd0;
                    idx2 <= 4'd0;
                    collision_found <= 1'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        signature[i] <= 16'd0;
                    end
                    next_state <= CHECK_SUB;
                end

                PREP_SORT: begin
                    // Copy buffer to candidate for sorting
                    for (i = 0; i < 16; i = i + 1) begin
                        candidate[i] <= buffer[i];
                    end
                    idx <= 4'd0; // Outer loop index
                    idx2 <= 4'd0; // Inner loop index
                    next_state <= SORT_LOOP;
                end

                SORT_LOOP: begin
                    // Bubble sort (simplified for compatibility)
                    // Only run for N elements
                    if (idx < N - 1) begin
                        if (idx2 < N - 1 - idx) begin
                            // Compare candidate[idx2] and candidate[idx2+1]
                            if (candidate[idx2] > candidate[idx2 + 1]) begin
                                // Swap
                                char_val <= candidate[idx2];
                                candidate[idx2] <= candidate[idx2 + 1];
                                candidate[idx2 + 1] <= char_val;
                            end
                            idx2 <= idx2 + 4'd1;
                            next_state <= SORT_LOOP;
                        end else begin
                            idx <= idx + 4'd1;
                            idx2 <= 4'd0;
                            next_state <= SORT_LOOP;
                        end
                    end else begin
                        // Sorting done
                        attempts <= attempts + 3'd1;
                        idx <= 4'd0;
                        idx2 <= 4'd0;
                        collision_found <= 1'b0;
                        for (i = 0; i < 16; i = i + 1) begin
                            signature[i] <= 16'd0;
                        end
                        next_state <= CHECK_SUB;
                    end
                end

                RESULT_FOUND: begin
                    // Prepare output from candidate
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < N) str_out[(i * 8) +: 8] <= candidate[i];
                        else str_out[(i * 8) +: 8] <= 8'd0;
                    end
                    impossible <= 1'b0;
                    result_valid <= 1'b1;
                    next_state <= OUTPUT_RESULT;
                end

                RESULT_FAIL: begin
                    // Set all output bytes to 0xFF
                    str_out <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
                    impossible <= 1'b1;
                    result_valid <= 1'b1;
                    next_state <= OUTPUT_RESULT;
                end

                OUTPUT_RESULT: begin
                    // Pulse done, then cleanup
                    result_valid <= 1'b0;
                    next_state <= CLEANUP;
                end

                CLEANUP: begin
                    // Return to idle
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // Frequency counting logic (embedded in CHECK_FREQ)
            if (state == CHECK_FREQ && idx < N) begin
                char_val <= buffer[idx];
                // Note: In a real synthesis, freq array would need async read
                // For simulation/synthesis compatibility, we increment directly
                // This is a simplified approach for the checker
                if (idx == 0) freq[buffer[0]] <= freq[buffer[0]] + 8'd1;
                else if (idx == 1) freq[buffer[1]] <= freq[buffer[1]] + 8'd1;
                else if (idx == 2) freq[buffer[2]] <= freq[buffer[2]] + 8'd1;
                else if (idx == 3) freq[buffer[3]] <= freq[buffer[3]] + 8'd1;
                else if (idx == 4) freq[buffer[4]] <= freq[buffer[4]] + 8'd1;
                else if (idx == 5) freq[buffer[5]] <= freq[buffer[5]] + 8'd1;
                else if (idx == 6) freq[buffer[6]] <= freq[buffer[6]] + 8'd1;
                else if (idx == 7) freq[buffer[7]] <= freq[buffer[7]] + 8'd1;
                else if (idx == 8) freq[buffer[8]] <= freq[buffer[8]] + 8'd1;
                else if (idx == 9) freq[buffer[9]] <= freq[buffer[9]] + 8'd1;
                else if (idx == 10) freq[buffer[10]] <= freq[buffer[10]] + 8'd1;
                else if (idx == 11) freq[buffer[11]] <= freq[buffer[11]] + 8'd1;
                else if (idx == 12) freq[buffer[12]] <= freq[buffer[12]] + 8'd1;
                else if (idx == 13) freq[buffer[13]] <= freq[buffer[13]] + 8'd1;
                else if (idx == 14) freq[buffer[14]] <= freq[buffer[14]] + 8'd1;
                else if (idx == 15) freq[buffer[15]] <= freq[buffer[15]] + 8'd1;
            end
            
            // Update max frequency during CHECK_FREQ state
            // (This is a simplified logic for the checker)
            if (state == CHECK_FREQ && idx < N) begin
                max_freq <= (freq[buffer[idx]] > max_freq) ? freq[buffer[idx]] : max_freq;
            end
        end
    end
endmodule