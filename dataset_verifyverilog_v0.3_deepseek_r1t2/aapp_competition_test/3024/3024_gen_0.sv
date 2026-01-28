module palindrome_partition_max #(
    parameter MAX_LEN = 16,
    parameter DIGIT_WIDTH = 4,
    parameter LEN_WIDTH = 4,
    parameter RESULT_WIDTH = 5
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DIGIT_WIDTH-1:0] str [0:MAX_LEN-1],
    input wire [LEN_WIDTH-1:0] len,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] S_IDLE         = 3'd0;
    localparam [2:0] S_CHECK_LOOP   = 3'd1;
    localparam [2:0] S_ADD_CHAR     = 3'd2;
    localparam [2:0] S_COMPARE      = 3'd3;
    localparam [2:0] S_NEXT_ITER    = 3'd4;
    localparam [2:0] S_HANDLE_MIDDLE= 3'd5;
    localparam [2:0] S_DONE         = 3'd6;

    reg [2:0] state, next_state;

    // Registered storage
    reg [DIGIT_WIDTH-1:0] str_reg [0:MAX_LEN-1];
    reg [LEN_WIDTH-1:0] len_reg;

    // Pointers and counters
    reg [LEN_WIDTH-1:0] l, r;
    reg [3:0] left_len, right_len; // Max 8 (half of 16)
    reg [DIGIT_WIDTH-1:0] left_seg [0:(MAX_LEN/2)-1];
    reg [DIGIT_WIDTH-1:0] right_seg [0:(MAX_LEN/2)-1];
    reg [RESULT_WIDTH-1:0] k;

    // Combinational equality check
    reg eq;
    integer i;
    always @(*) begin
        eq = 1'b1;
        if (left_len != right_len) begin
            eq = 1'b0;
        end else begin
            for (i = 0; i < (MAX_LEN/2); i = i + 1) begin
                if (i < left_len) begin
                    if (left_seg[i] != right_seg[left_len-1-i]) begin
                        eq = 1'b0;
                    end
                end
            end
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:          next_state = start ? S_CHECK_LOOP : S_IDLE;
            S_CHECK_LOOP:    next_state = (l < r) ? S_ADD_CHAR : S_HANDLE_MIDDLE;
            S_ADD_CHAR:      next_state = S_COMPARE;
            S_COMPARE:       next_state = S_NEXT_ITER;
            S_NEXT_ITER:     next_state = S_CHECK_LOOP;
            S_HANDLE_MIDDLE: next_state = S_DONE;
            S_DONE:          next_state = S_IDLE;
            default:         next_state = S_IDLE;
        endcase
    end

    // Sequential logic
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b0}};
            l <= {LEN_WIDTH{1'b0}};
            r <= {LEN_WIDTH{1'b0}};
            left_len <= 4'd0;
            right_len <= 4'd0;
            k <= {RESULT_WIDTH{1'b0}};
            // Initialize arrays
            for (j = 0; j < MAX_LEN; j = j + 1) begin
                str_reg[j] <= {DIGIT_WIDTH{1'b0}};
            end
            for (j = 0; j < MAX_LEN/2; j = j + 1) begin
                left_seg[j] <= {DIGIT_WIDTH{1'b0}};
                right_seg[j] <= {DIGIT_WIDTH{1'b0}};
            end
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs
                        for (j = 0; j < MAX_LEN; j = j + 1) begin
                            str_reg[j] <= str[j];
                        end
                        len_reg <= len;
                        // Initialize counters
                        l <= { {LEN_WIDTH-1{1'b0}} , 1'b1 }; // start at 0
                        r <= len - 1;
                        left_len <= 4'd0;
                        right_len <= 4'd0;
                        k <= {RESULT_WIDTH{1'b0}};
                    end
                end

                S_CHECK_LOOP: begin
                    // No action; transition handled above
                end

                S_ADD_CHAR: begin
                    left_seg[left_len] <= str_reg[l];
                    left_len <= left_len + 4'd1;
                    right_seg[right_len] <= str_reg[r];
                    right_len <= right_len + 4'd1;
                end

                S_COMPARE: begin
                    if (eq) begin
                        k <= k + RESULT_WIDTH'd2; // Matched two palindromic segments
                        left_len <= 4'd0;
                        right_len <= 4'd0;
                    end
                    // If not equal, segments remain for next comparison
                end

                S_NEXT_ITER: begin
                    l <= l + 1;
                    r <= r - 1;
                end

                S_HANDLE_MIDDLE: begin
                    // Check for remaining middle character or unmatched segments
                    if (l == r) begin
                        k <= k + RESULT_WIDTH'd1;
                    end else if (left_len != 4'd0 || right_len != 4'd0) begin
                        k <= k + RESULT_WIDTH'd1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    result <= k;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule