module HandsomeNumberFinder (
    input clk,
    input rst_n,
    input start,
    input [63:0] n_in,
    output reg [63:0] result0,
    output reg [63:0] result1,
    output reg [1:0] count,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] CHECK_HANDESSOME = 3'd1;
    localparam [2:0] SEARCH_UP       = 3'd2;
    localparam [2:0] SEARCH_DOWN     = 3'd3;
    localparam [2:0] DONE_STATE      = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [63:0] n_reg;
    reg [63:0] search_val;
    reg [63:0] result0_reg;
    reg [63:0] result1_reg;
    reg [1:0] count_reg;
    reg [3:0] digits [0:15]; // 16 digits, 4 bits each
    reg [4:0] digit_count;   // 0-16 digits
    reg [4:0] digit_idx;
    reg [15:0] iteration_cnt;
    reg [15:0] max_iterations;
    reg is_handsome;
    reg found_up;
    reg found_down;
    reg search_dir; // 0=up, 1=down
    reg signed [64:0] temp_sub; // For signed arithmetic
    reg [63:0] temp_add;
    reg [3:0] last_parity;
    reg [3:0] current_parity;
    reg search_complete;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 64'd0;
            search_val <= 64'd0;
            result0_reg <= 64'd0;
            result1_reg <= 64'd0;
            count_reg <= 2'd0;
            done <= 1'b0;
            digit_count <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                digits[i] <= 4'd0;
            end
            digit_idx <= 5'd0;
            iteration_cnt <= 16'd0;
            max_iterations <= 16'd1000;
            is_handsome <= 1'b0;
            found_up <= 1'b0;
            found_down <= 1'b0;
            search_dir <= 1'b0;
            temp_sub <= 65'sd0;
            temp_add <= 64'd0;
            last_parity <= 4'd0;
            current_parity <= 4'd0;
            search_complete <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result0 <= 64'd0;
                    result1 <= 64'd0;
                    count <= 2'd0;
                    if (start) begin
                        n_reg <= n_in;
                        search_val <= n_in;
                        digit_count <= 5'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            digits[i] <= 4'd0;
                        end
                        digit_idx <= 5'd15;
                        is_handsome <= 1'b1;
                        last_parity <= 4'd15; // Initialize to invalid
                        state <= CHECK_HANDESSOME;
                    end
                end

                CHECK_HANDESSOME: begin
                    if (digit_idx == 5'd15 && digit_count == 5'd0) begin
                        // First iteration, extract digits
                        if (n_reg == 64'd0) begin
                            digits[15] <= 4'd0;
                            digit_count <= 5'd1;
                            digit_idx <= 5'd15;
                            // Check 0 immediately
                            if (0 % 2 == 0) last_parity <= 4'd0;
                            else last_parity <= 4'd1;
                        end else begin
                            // Extract lowest digit
                            digits[digit_idx] <= n_reg[3:0];
                            current_parity <= n_reg[0];
                            n_reg <= {4'd0, n_reg[63:4]};
                            digit_idx <= digit_idx - 5'd1;
                            digit_count <= digit_count + 5'd1;
                        end
                    end else if (digit_idx < 5'd15) begin
                        // Continue extracting
                        digits[digit_idx] <= n_reg[3:0];
                        current_parity <= n_reg[0];
                        n_reg <= {4'd0, n_reg[63:4]};
                        digit_idx <= digit_idx - 5'd1;
                        if (n_reg[3:0] != 4'd0 || n_reg[63:4] != 64'd0) begin
                            digit_count <= digit_count + 5'd1;
                        end
                    end else begin
                        // Extraction complete, checking alternation
                        if (digit_count == 5'd1) begin
                            // Single digit is always handsome
                            is_handsome <= 1'b1;
                        end else begin
                            // Check alternation on extracted digits
                            // We extracted from LSB to MSB, so check from digit_idx+1 to 15
                            // Actually, we need to check from MSB to LSB
                            // Let's re-index: digits[digit_idx+1] is MSB, digits[15] is LSB
                            if (digit_idx + 5'd1 >= 5'd15) begin
                                // Start check loop
                                // We need to check digits[idx+1] vs digits[idx+2] for parity
                                // Let's do a scan
                                // Reset check loop vars
                                digit_idx <= digit_idx + 5'd2; // Start at second digit
                                last_parity <= digits[digit_idx + 5'd1][0]; // First digit parity
                            end else begin
                                // Continue scan
                                if (digits[digit_idx][0] == last_parity) begin
                                    is_handsome <= 1'b0;
                                    // Done checking
                                end else begin
                                    last_parity <= digits[digit_idx][0];
                                    if (digit_idx + 5'd1 >= 5'd15) begin
                                        // Reached end of number
                                        is_handsome <= 1'b1;
                                    end
                                end
                                digit_idx <= digit_idx + 5'd1;
                            end
                        end
                    end

                    // Transition logic
                    if (digit_idx == 5'd15 && digit_count > 5'd1) begin
                        // Extraction done, start check
                        digit_idx <= 5'd0; // Start index for checking
                    end
                    if ((digit_count > 5'd1 && digit_idx >= 5'd15 && digit_count > 5'd0) || 
                        (digit_count <= 5'd1 && digit_count > 5'd0)) begin
                        // Check complete or single digit
                        state <= DONE_STATE;
                        if (is_handsome) begin
                            result0_reg <= n_in;
                            result1_reg <= 64'd0;
                            count_reg <= 2'd1;
                            done <= 1'b1;
                        end else begin
                            // Setup search
                            found_up <= 1'b0;
                            found_down <= 1'b0;
                            iteration_cnt <= 16'd0;
                            search_val <= n_in;
                            search_dir <= 1'b0; // Start with UP
                            result0_reg <= 64'd0;
                            result1_reg <= 64'd0;
                            count_reg <= 2'd0;
                        end
                    end
                    // Re-do extraction check properly
                    // This state is messy, let's simplify extraction into a helper logic
                    // Actually, let's use a simpler digit extraction loop
                end

                SEARCH_UP: begin
                    if (found_up) begin
                        // Already found up, switch to down
                        state <= SEARCH_DOWN;
                    end else begin
                        // Search upwards
                        temp_add <= search_val + 64'd1;
                        search_val <= search_val + 64'd1;
                        iteration_cnt <= iteration_cnt + 16'd1;
                        // Check limit
                        if (iteration_cnt >= max_iterations) begin
                            state <= DONE_STATE;
                            if (count_reg == 2'd1) begin
                                // Only found down
                                result1_reg <= 64'd0;
                            end
                            done <= 1'b1;
                        end
                        // Check handsome (delayed by 1 cycle for logic)
                        // We need to check the value added in previous cycle?
                        // No, check current search_val (which is N+iter)
                        // Actually, check temp_add
                        // Handshake: extract digits of temp_add
                        digit_count <= 5'd0;
                        n_reg <= temp_add;
                        digit_idx <= 5'd15;
                        // We need a sub-state for checking
                        // Let's add a CHECK state or re-use CHECK_HANDESSOME
                        // Re-use CHECK_HANDESSOME but set a flag
                    end
                end

                SEARCH_DOWN: begin
                    // Similar to up
                end

                DONE_STATE: begin
                    result0 <= result0_reg;
                    result1 <= result1_reg;
                    count <= count_reg;
                    // done already set
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Helper logic for digit extraction and check
    // To avoid complexity, let's merge extraction into SEARCH states
    // But the constraint says: "Pipeline: one comparison per clock cycle"
    // This implies we need to separate extraction and checking.
    // Let's add a sub-state or use counters.

    // Redesign of CHECK_HANDESSOME and SEARCH states:
    // We need a unified digit extractor that checks alternation.
    // Let's add a dedicated check logic block.

    // Logic for checking handsomeness of a value in n_reg
    reg [3:0] check_digits [0:15];
    reg [4:0] check_idx;
    reg [4:0] check_len;
    reg check_done;
    reg check_result;
    reg checking_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            checking_active <= 1'b0;
            check_done <= 1'b0;
            check_result <= 1'b0;
        end else begin
            if (checking_active) begin
                if (check_idx == 5'd16) begin
                    // Extraction complete, start check
                    // Check from MSB to LSB
                    // check_len has the length
                    if (check_len <= 5'd1) begin
                        check_result <= 1'b1;
                        check_done <= 1'b1;
                        checking_active <= 1'b0;
                    end else begin
                        // Start alternation check
                        check_idx <= 5'd0; // Reuse for check loop
                        check_done <= 1'b0;
                    end
                end else if (check_idx < 5'd16) begin
                    // Extracting digits
                    check_digits[check_idx] <= n_reg[3:0];
                    n_reg <= {4'd0, n_reg[63:4]};
                    if (n_reg[3:0] != 4'd0 || n_reg[63:4] != 64'd0) begin
                        check_len <= check_len + 5'd1;
                    end
                    check_idx <= check_idx + 5'd1;
                end else begin
                    // Check loop
                    if (check_idx == 5'd0) begin
                        // Check first pair
                        if (check_digits[check_len-1][0] == check_digits[check_len-2][0]) begin
                            check_result <= 1'b0;
                            check_done <= 1'b1;
                            checking_active <= 1'b0;
                        end else begin
                            check_idx <= check_idx + 5'd2;
                        end
                    end else begin
                        if (check_idx < check_len) begin
                            if (check_digits[check_len - check_idx][0] == check_digits[check_len - check_idx - 1][0]) begin
                                check_result <= 1'b0;
                                check_done <= 1'b1;
                                checking_active <= 1'b0;
                            end else begin
                                check_idx <= check_idx + 5'd2;
                            end
                        end else begin
                            check_result <= 1'b1;
                            check_done <= 1'b1;
                            checking_active <= 1'b0;
                        end
                    end
                end
            end
        end
    end

    // Since the check logic is complex, let's simplify the FSM to be less state-heavy
    // and more sequential.
    // The prompt asks for "Pipeline: one comparison per clock cycle". 
    // This usually means one step of the search per cycle.
    // Since we need to check digits, we need multiple cycles for that check.
    // So one "comparison" = checking a number.

    // Let's rewrite the FSM cleanly.

endmodule
