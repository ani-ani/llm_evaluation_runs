module longest_repeated_substring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] str_len,
    input wire [7:0] str [0:15],
    output reg [3:0] result_len,
    output reg [3:0] result_start,
    output reg [7:0] result_str [0:15],
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT_CHECK    = 3'd1;
    localparam [2:0] CHECK_LEN     = 3'd2;
    localparam [2:0] CHECK_POS     = 3'd3;
    localparam [2:0] VERIFY_REPEAT = 3'd4;
    localparam [2:0] UPDATE_BEST   = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] L;                    // Current substring length being checked
    reg [3:0] i;                    // First occurrence start position
    reg [3:0] j;                    // Second occurrence start position
    reg [3:0] best_len;             // Best length found so far
    reg [3:0] best_start;           // Best start position for best length
    reg [7:0] best_str [0:15];      // Best substring found
    reg [3:0] compare_idx;          // Index for byte-wise comparison
    reg is_repeat;                  // Flag if current substring repeats
    reg lexicographically_smaller;  // Flag if new substring is lex smaller
    reg [3:0] cycle_count;          // Safety counter
    localparam [3:0] MAX_CYCLES = 4'd12; // 1000/100 > 12, but safe

    integer k; // Loop index

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_len <= 4'd0;
            result_start <= 4'd0;
            for (k = 0; k < 16; k = k + 1) begin
                result_str[k] <= 8'd0;
            end
            done <= 1'b0;
            busy <= 1'b0;
            L <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            best_len <= 4'd0;
            best_start <= 4'd0;
            for (k = 0; k < 16; k = k + 1) begin
                best_str[k] <= 8'd0;
            end
            compare_idx <= 4'd0;
            is_repeat <= 1'b0;
            lexicographically_smaller <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        busy <= 1'b1;
                        best_len <= 4'd0;
                        best_start <= 4'd0;
                        for (k = 0; k < 16; k = k + 1) begin
                            best_str[k] <= 8'd0;
                        end
                        L <= (str_len > 4'd0) ? str_len : 4'd1;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end

                INIT_CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    is_repeat <= 1'b0;
                    lexicographically_smaller <= 1'b0;
                    j <= i + 4'd1;
                    compare_idx <= 4'd0;
                end

                CHECK_POS: begin
                    if (j <= str_len - L) begin
                        compare_idx <= 4'd0;
                    end
                end

                VERIFY_REPEAT: begin
                    if (compare_idx < L) begin
                        if (str[i + compare_idx] == str[j + compare_idx]) begin
                            if (compare_idx + 4'd1 == L) begin
                                is_repeat <= 1'b1;
                            end else begin
                                compare_idx <= compare_idx + 4'd1;
                            end
                        end else begin
                            compare_idx <= L;
                        end
                    end
                end

                UPDATE_BEST: begin
                    if (is_repeat) begin
                        if (L > best_len) begin
                            best_len <= L;
                            best_start <= i;
                            for (k = 0; k < 16; k = k + 1) begin
                                if (k < L) begin
                                    best_str[k] <= str[i + k];
                                end else begin
                                    best_str[k] <= 8'd0;
                                end
                            end
                        end else if (L == best_len && L > 4'd0) begin
                            compare_idx <= 4'd0;
                            lexicographically_smaller <= 1'b0;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result_len <= best_len;
                    result_start <= best_start;
                    for (k = 0; k < 16; k = k + 1) begin
                        result_str[k] <= best_str[k];
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_CHECK;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT_CHECK: begin
                if (str_len == 4'd0 || L < 4'd1) begin
                    next_state = FINISH;
                end else if (i <= str_len - L) begin
                    next_state = CHECK_POS;
                end else begin
                    if (L > 4'd1) begin
                        next_state = INIT_CHECK;
                    end else begin
                        next_state = FINISH;
                    end
                end
            end

            CHECK_POS: begin
                if (j <= str_len - L) begin
                    next_state = VERIFY_REPEAT;
                end else begin
                    next_state = INIT_CHECK;
                end
            end

            VERIFY_REPEAT: begin
                if (compare_idx == L) begin
                    next_state = UPDATE_BEST;
                end else if (compare_idx > L) begin
                    next_state = CHECK_POS;
                end else begin
                    next_state = VERIFY_REPEAT;
                end
            end

            UPDATE_BEST: begin
                if (is_repeat) begin
                    if (L == best_len && L > 4'd0) begin
                        if (compare_idx < L) begin
                            if (str[i + compare_idx] < str[best_start + compare_idx]) begin
                                lexicographically_smaller <= 1'b1;
                            end else if (str[i + compare_idx] > str[best_start + compare_idx]) begin
                                lexicographically_smaller <= 1'b0;
                            end
                            if (str[i + compare_idx] != str[best_start + compare_idx]) begin
                                compare_idx <= L;
                            end else begin
                                compare_idx <= compare_idx + 4'd1;
                            end
                            next_state = UPDATE_BEST;
                        end else begin
                            if (lexicographically_smaller || (best_len == 4'd0)) begin
                                best_start <= i;
                                for (k = 0; k < 16; k = k + 1) begin
                                    if (k < L) begin
                                        best_str[k] <= str[i + k];
                                    end else begin
                                        best_str[k] <= 8'd0;
                                    end
                                end
                            end
                            j <= j + 4'd1;
                            next_state = CHECK_POS;
                        end
                    end else begin
                        j <= j + 4'd1;
                        next_state = CHECK_POS;
                    end
                end else begin
                    j <= j + 4'd1;
                    next_state = CHECK_POS;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase

        // Update loops in INIT_CHECK
        if (state == INIT_CHECK) begin
            if (i > str_len - L) begin
                if (L > 4'd1) begin
                    L <= L - 4'd1;
                    i <= 4'd0;
                end
            end else if (is_repeat == 1'b1) begin
                i <= i + 4'd1;
            end else if (i < str_len - L) begin
                i <= i + 4'd1;
            end
            is_repeat <= 1'b0;
        end

        if (state == IDLE && start) begin
            if (str_len > 4'd0) begin
                L <= str_len;
            end else begin
                L <= 4'd1;
            end
            i <= 4'd0;
            is_repeat <= 1'b0;
        end
    end

endmodule