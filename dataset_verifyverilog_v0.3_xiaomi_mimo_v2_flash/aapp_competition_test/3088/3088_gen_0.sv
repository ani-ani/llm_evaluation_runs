module largest_number_after_k_swaps (
    input [13:0] n,
    input [4:0] k,
    output reg [13:0] result
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SETUP      = 3'd1;
    localparam [2:0] FIND_MAX   = 3'd2;
    localparam [2:0] SWAP       = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [13:0] current_n;
    reg [13:0] n_digits [3:0]; // Stores individual digits
    reg [3:0] i, j;            // Loop counters
    reg [3:0] max_idx;
    reg [3:0] remaining_k;
    reg [13:0] temp_val;
    reg [3:0] digits_len;
    reg done_flag;
    integer loop_i, loop_j;

    // Compute next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: next_state = SETUP;
            SETUP: next_state = FIND_MAX;
            FIND_MAX: next_state = SWAP;
            SWAP: begin
                if (i < digits_len && j <= i && remaining_k > 0 && n_digits[j] < n_digits[i]) begin
                    next_state = SWAP; // Continue checking for this position
                end else if (i < digits_len && j <= i && remaining_k > 0 && n_digits[j] == n_digits[i]) begin
                    next_state = SWAP; // Continue checking for this position
                end else if (i < digits_len && remaining_k > 0) begin
                    next_state = SWAP; // Next position
                end else begin
                    next_state = FINISH;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 14'd0;
            current_n <= 14'd0;
            i <= 4'd0;
            j <= 4'd0;
            max_idx <= 4'd0;
            remaining_k <= 5'd0;
            temp_val <= 14'd0;
            digits_len <= 4'd0;
            done_flag <= 1'b0;
            for (loop_i = 0; loop_i < 4; loop_i = loop_i + 1) begin
                n_digits[loop_i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done_flag <= 1'b0;
                    if (n > 14'd0) begin
                        state <= next_state;
                    end
                end

                SETUP: begin
                    // Extract digits from n (0-9999 has up to 4 digits)
                    current_n <= n;
                    n_digits[3] <= n % 4'd10;
                    n_digits[2] <= (n / 4'd10) % 4'd10;
                    n_digits[1] <= (n / 4'd100) % 4'd10;
                    n_digits[0] <= (n / 4'd1000) % 4'd10;
                    // Determine length (1 to 4)
                    if (n >= 4'd1000) digits_len <= 4'd4;
                    else if (n >= 4'd100) digits_len <= 4'd3;
                    else if (n >= 4'd10) digits_len <= 4'd2;
                    else if (n >= 4'd1) digits_len <= 4'd1;
                    else digits_len <= 4'd1;
                    i <= 4'd0;
                    j <= 4'd1;
                    remaining_k <= k;
                    state <= next_state;
                end

                FIND_MAX: begin
                    // Find max digit from position i to end
                    max_idx <= i;
                    temp_val <= n_digits[i];
                    j <= i + 4'd1;
                    state <= SWAP;
                end

                SWAP: begin
                    // Update max index if current digit is larger
                    if (j < digits_len && n_digits[j] > temp_val) begin
                        temp_val <= n_digits[j];
                        max_idx <= j;
                    end

                    // If we've checked all digits, perform swap if k > 0
                    if (j == digits_len) begin
                        if (remaining_k > 4'd0 && max_idx > i && n_digits[max_idx] > n_digits[i]) begin
                            // Swap n_digits[i] and n_digits[max_idx]
                            n_digits[i] <= n_digits[max_idx];
                            n_digits[max_idx] <= n_digits[i];
                            remaining_k <= remaining_k - 5'd1;
                        end
                        // Move to next position
                        i <= i + 4'd1;
                    end
                    // Continue loop
                    j <= j + 4'd1;
                    state <= next_state;
                end

                FINISH: begin
                    // Reconstruct number from digits
                    result <= n_digits[0] * 14'd1000 + n_digits[1] * 14'd100 + n_digits[2] * 14'd10 + n_digits[3];
                    done_flag <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule