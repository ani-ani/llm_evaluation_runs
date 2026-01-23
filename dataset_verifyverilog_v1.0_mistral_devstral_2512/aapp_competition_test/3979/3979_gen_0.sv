module bookland_ordering(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [3:0] word_len [0:7],
    input wire [31:0] word_data [0:7],
    output reg yes,
    output reg [3:0] k,
    output reg [7:0] letters_out,
    output reg done
);

    parameter MAX_WORDS = 8;
    parameter MAX_LEN = 8;
    parameter MAX_M = 8;

    localparam [2:0] S_IDLE = 3'b000;
    localparam [2:0] S_CHECK_MASK = 3'b001;
    localparam [2:0] S_CHECK_PAIR = 3'b010;
    localparam [2:0] S_NEXT_MASK = 3'b011;
    localparam [2:0] S_FOUND = 3'b100;
    localparam [2:0] S_NO_RESULT = 3'b101;
    localparam [2:0] S_OUTPUT = 3'b110;

    reg [2:0] state;
    reg [2:0] pair_idx;
    reg [MAX_M-1:0] current_mask;

    wire [3:0] w1_len, w2_len;
    wire [31:0] w1_data, w2_data;
    wire valid;

    assign w1_len = (pair_idx < n) ? word_len[pair_idx] : 4'd0;
    assign w1_data = (pair_idx < n) ? word_data[pair_idx] : 32'd0;
    assign w2_len = (pair_idx + 1 < n) ? word_len[pair_idx + 1] : 4'd0;
    assign w2_data = (pair_idx + 1 < n) ? word_data[pair_idx + 1] : 32'd0;

    always @(*) begin
        reg [3:0] a, b;
        reg cap_a, cap_b;
        reg diff_found;
        reg valid_int;
        integer j;

        diff_found = 0;
        valid_int = 1;

        for (j = 0; j < MAX_LEN; j = j + 1) begin
            if (!diff_found && j < w1_len && j < w2_len) begin
                a = w1_data[j*4 +: 4];
                b = w2_data[j*4 +: 4];
                if (a != b) begin
                    diff_found = 1;
                    cap_a = current_mask[a-1];
                    cap_b = current_mask[b-1];
                    if (cap_a == cap_b) begin
                        valid_int = (a < b);
                    end else if (cap_a < cap_b) begin
                        valid_int = 1;
                    end else begin
                        valid_int = 0;
                    end
                end
            end
        end

        if (!diff_found) begin
            valid_int = (w1_len <= w2_len);
        end

        valid = valid_int;
    end

    function automatic [3:0] count_bits(input [MAX_M-1:0] mask);
        reg [3:0] cnt;
        integer i;
        cnt = 0;
        for (i = 0; i < MAX_M; i = i + 1) begin
            if (mask[i]) cnt = cnt + 1;
        end
        count_bits = cnt;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            yes <= 0;
            k <= 0;
            letters_out <= 0;
            done <= 0;
            current_mask <= 0;
            pair_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (n <= 1) begin
                            yes <= 1;
                            letters_out <= 0;
                            k <= 0;
                            state <= S_OUTPUT;
                        end else begin
                            current_mask <= 0;
                            state <= S_CHECK_MASK;
                        end
                    end
                end

                S_CHECK_MASK: begin
                    pair_idx <= 0;
                    state <= S_CHECK_PAIR;
                end

                S_CHECK_PAIR: begin
                    if (!valid) begin
                        state <= S_NEXT_MASK;
                    end else begin
                        if (pair_idx == n-2) begin
                            state <= S_FOUND;
                        end else begin
                            pair_idx <= pair_idx + 1;
                        end
                    end
                end

                S_NEXT_MASK: begin
                    if (current_mask == (1 << m) - 1) begin
                        state <= S_NO_RESULT;
                    end else begin
                        current_mask <= current_mask + 1;
                        state <= S_CHECK_MASK;
                    end
                end

                S_FOUND: begin
                    yes <= 1;
                    letters_out <= current_mask;
                    k <= count_bits(current_mask);
                    state <= S_OUTPUT;
                end

                S_NO_RESULT: begin
                    yes <= 0;
                    letters_out <= 0;
                    k <= 0;
                    state <= S_OUTPUT;
                end

                S_OUTPUT: begin
                    done <= 1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule