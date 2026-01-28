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
    localparam [2:0] S_IDLE = 3'b000;
    localparam [2:0] S_CHECK_LOOP = 3'b001;
    localparam [2:0] S_ADD_CHAR = 3'b010;
    localparam [2:0] S_COMPARE = 3'b011;
    localparam [2:0] S_NEXT_ITER = 3'b100;
    localparam [2:0] S_HANDLE_MIDDLE = 3'b101;
    localparam [2:0] S_DONE = 3'b110;

    // Registers for input storage
    reg [DIGIT_WIDTH-1:0] str_reg [0:MAX_LEN-1];
    reg [LEN_WIDTH-1:0] len_reg;

    // Pointers and counters
    reg [LEN_WIDTH-1:0] l, r;
    reg [3:0] left_len, right_len;
    reg [DIGIT_WIDTH-1:0] left_seg [0:(MAX_LEN/2)-1];
    reg [DIGIT_WIDTH-1:0] right_seg [0:(MAX_LEN/2)-1];
    reg [RESULT_WIDTH-1:0] k;

    // State registers
    reg [2:0] state, next_state;

    // Comparator combinational logic
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

    // State transition combinational logic
    always @(*) begin
        case (state)
            S_IDLE: next_state = start ? S_CHECK_LOOP : S_IDLE;
            S_CHECK_LOOP: next_state = (l < r) ? S_ADD_CHAR : S_HANDLE_MIDDLE;
            S_ADD_CHAR: next_state = S_COMPARE;
            S_COMPARE: next_state = S_NEXT_ITER;
            S_NEXT_ITER: next_state = S_CHECK_LOOP;
            S_HANDLE_MIDDLE: next_state = S_DONE;
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b0}};
            left_len <= 4'd0;
            right_len <= 4'd0;
            k <= {RESULT_WIDTH{1'b0}};
            l <= {LEN_WIDTH{1'b0}};
            r <= {LEN_WIDTH{1'b0}};
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture input string and length
                        integer j;
                        for (j = 0; j < MAX_LEN; j = j + 1) begin
                            str_reg[j] <= str[j];
                        end
                        len_reg <= len;
                        // Initialize counters
                        l <= 4'd0;
                        r <= len - 1;
                        left_len <= 4'd0;
                        right_len <= 4'd0;
                        k <= {RESULT_WIDTH{1'b0}};
                    end
                end

                S_ADD_CHAR: begin
                    // Add character from left and right
                    left_seg[left_len] <= str_reg[l];
                    left_len <= left_len + 4'd1;
                    right_seg[right_len] <= str_reg[r];
                    right_len <= right_len + 4'd1;
                end

                S_COMPARE: begin
                    if (eq) begin
                        k <= k + 5'd2;
                        left_len <= 4'd0;
                        right_len <= 4'd0;
                    end
                end

                S_NEXT_ITER: begin
                    l <= l + 4'd1;
                    r <= r - 4'd1;
                end

                S_HANDLE_MIDDLE: begin
                    if (left_len != 4'd0 || right_len != 4'd0) begin
                        k <= k + 5'd1;
                    end else if (l == r) begin
                        k <= k + 5'd1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    result <= k;
                end

                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule