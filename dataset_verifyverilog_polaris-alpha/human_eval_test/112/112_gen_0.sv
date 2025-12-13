module string_filter_palindrome(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [7:0]  s_chars [7:0],
    input  wire [7:0]  c_chars [7:0],
    input  wire [2:0]  s_len,
    input  wire [2:0]  c_len,
    output reg  [7:0]  result_chars [7:0],
    output reg  [2:0]  result_len,
    output reg         is_palindrome,
    output reg         done
);

    reg [3:0]  cycle_cnt;
    reg [7:0]  filt_chars [7:0];
    reg [2:0]  filt_len;
    reg        pal_ok;

    integer i, j;

    // Synchronous control and operations
    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_cnt     <= 4'd0;
            result_len    <= 3'd0;
            is_palindrome <= 1'b1;
            done          <= 1'b0;
            pal_ok        <= 1'b1;
            for (i = 0; i < 8; i = i + 1) begin
                result_chars[i] <= 8'd0;
                filt_chars[i]   <= 8'd0;
            end
        end else begin
            done <= 1'b0;

            // Start pulse latches a new operation if idle
            if (start && (cycle_cnt == 4'd0)) begin
                // Filtering: 1 cycle
                filt_len = 3'd0;
                for (i = 0; i < 8; i = i + 1) begin
                    // Only consider up to s_len (0-based index)
                    if (i < s_len) begin
                        // Check if s_chars[i] should be deleted
                        reg delete_flag;
                        delete_flag = 1'b0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (j < c_len) begin
                                if (s_chars[i] == c_chars[j]) begin
                                    delete_flag = 1'b1;
                                end
                            end
                        end
                        // Keep character if not deleted
                        if (!delete_flag) begin
                            filt_chars[filt_len] = s_chars[i];
                            filt_len = filt_len + 3'd1;
                        end
                    end
                end
                // Zero out remaining unused positions
                for (i = filt_len; i < 8; i = i + 1) begin
                    filt_chars[i] = 8'd0;
                end

                // Initialize palindrome check state
                result_len    <= filt_len;
                pal_ok        <= 1'b1; // assume true; will clear if mismatch
                is_palindrome <= 1'b0; // will be updated at completion

                // Latch filtered chars to result_chars for palindrome phase
                for (i = 0; i < 8; i = i + 1) begin
                    result_chars[i] <= filt_chars[i];
                end

                // Move to cycle 1 (filter just performed)
                cycle_cnt <= 4'd1;
            end else if (cycle_cnt != 4'd0) begin
                // Palindrome check across cycles 1-8
                // Each cycle checks up to one pair (index = cycle_cnt - 1)

                // Compute pair index and valid comparisons
                reg [2:0] pair_idx;
                reg [2:0] last_idx;
                reg       cmp_valid;

                pair_idx  = cycle_cnt - 4'd1; // 0..7 over cycles 1..8
                last_idx  = (result_len == 0) ? 3'd0 : (result_len - 3'd1);
                cmp_valid = 1'b0;

                if (result_len <= 1) begin
                    // length 0 or 1 always palindrome; no comparisons needed
                    cmp_valid = 1'b0;
                end else begin
                    // Only compare if pair_idx is within first half
                    // pair_idx < (result_len >> 1)
                    if (pair_idx < (result_len >> 1)) begin
                        cmp_valid = 1'b1;
                    end
                end

                if (cmp_valid && pal_ok) begin
                    if (result_chars[pair_idx] != result_chars[last_idx - pair_idx]) begin
                        pal_ok <= 1'b0;
                    end
                end

                // Advance cycle counter; complete at cycle 9
                if (cycle_cnt == 4'd9) begin
                    // Finalize outputs
                    is_palindrome <= (pal_ok || (result_len <= 1));
                    done          <= 1'b1;
                    cycle_cnt     <= 4'd0; // return to idle
                end else begin
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
            end
        end
    end

endmodule