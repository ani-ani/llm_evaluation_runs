module RobbersWatch (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    input wire [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_LEN_H = 4'd1;
    localparam [3:0] COMPUTE_LEN_M = 4'd2;
    localparam [3:0] CHECK_LEN = 4'd3;
    localparam [3:0] INIT_PERM = 4'd4;
    localparam [3:0] EVAL_PERM = 4'd5;
    localparam [3:0] NEXT_PERM = 4'd6;
    localparam [3:0] NEXT_COMB = 4'd7;
    localparam [3:0] DONE = 4'd8;

    // Registers
    reg [3:0] state;
    reg [31:0] n_reg, m_reg;
    reg [3:0] len_h, len_m;
    reg [2:0] L;
    reg [6:0] current_bitmask;
    reg [2:0] current_perm [0:6];
    reg [31:0] count;
    reg [2:0] i, j;
    reg [2:0] phase;
    reg [2:0] hour_value, minute_value;
    reg [2:0] hour_digits [0:6];
    reg [2:0] minute_digits [0:6];

    // Powers of 7
    wire [20:0] pow7 [0:7];
    assign pow7[0] = 21'd1;
    assign pow7[1] = 21'd7;
    assign pow7[2] = 21'd49;
    assign pow7[3] = 21'd343;
    assign pow7[4] = 21'd2401;
    assign pow7[5] = 21'd16807;
    assign pow7[6] = 21'd117649;
    assign pow7[7] = 21'd823543;

    // Helper function to compute number of digits
    function [3:0] compute_len;
        input [31:0] val;
        begin
            if (val == 0) compute_len = 4'd1;
            else if (val < 7) compute_len = 4'd1;
            else if (val < 49) compute_len = 4'd2;
            else if (val < 343) compute_len = 4'd3;
            else if (val < 2401) compute_len = 4'd4;
            else if (val < 16807) compute_len = 4'd5;
            else if (val < 117649) compute_len = 4'd6;
            else if (val < 823543) compute_len = 4'd7;
            else compute_len = 4'd8;
        end
    endfunction

    // Helper function to compute value from digits
    function [20:0] compute_value;
        input [2:0] len;
        input [2:0] digits [0:6];
        integer k;
        begin
            compute_value = 21'd0;
            for (k = 0; k < len; k = k + 1) begin
                compute_value = compute_value * 7 + digits[k];
            end
        end
    endfunction

    // Helper function to count bits in a 7-bit mask
    function [3:0] popcount;
        input [6:0] bits;
        integer k;
        begin
            popcount = 4'd0;
            for (k = 0; k < 7; k = k + 1) popcount = popcount + bits[k];
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 32'd0;
            m_reg <= 32'd0;
            len_h <= 4'd0;
            len_m <= 4'd0;
            L <= 3'd0;
            current_bitmask <= 7'd0;
            for (integer idx = 0; idx < 7; idx = idx + 1) current_perm[idx] <= 3'd0;
            count <= 32'd0;
            i <= 3'd0;
            j <= 3'd0;
            phase <= 3'd0;
            hour_value <= 3'd0;
            minute_value <= 3'd0;
            for (integer idx = 0; idx < 7; idx = idx + 1) hour_digits[idx] <= 3'd0;
            for (integer idx = 0; idx < 7; idx = idx + 1) minute_digits[idx] <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        m_reg <= m;
                        state <= COMPUTE_LEN_H;
                    end
                end

                COMPUTE_LEN_H: begin
                    len_h <= compute_len((n_reg == 1) ? 0 : n_reg - 1);
                    state <= COMPUTE_LEN_M;
                end

                COMPUTE_LEN_M: begin
                    len_m <= compute_len((m_reg == 1) ? 0 : m_reg - 1);
                    state <= CHECK_LEN;
                end

                CHECK_LEN: begin
                    if (len_h + len_m > 7) begin
                        result <= 32'd0;
                        state <= DONE;
                    end else begin
                        L <= len_h + len_m;
                        count <= 32'd0;
                        current_bitmask <= 7'b0000001;
                        state <= INIT_PERM;
                    end
                end

                INIT_PERM: begin
                    // Initialize permutation to sorted combination
                    integer idx;
                    integer pos;
                    for (idx = 0; idx < 7; idx = idx + 1) current_perm[idx] <= 3'd0;
                    pos <= 3'd0;
                    for (idx = 0; idx < 7; idx = idx + 1) begin
                        if (current_bitmask[idx]) begin
                            current_perm[pos] <= idx;
                            pos <= pos + 1;
                        end
                    end
                    state <= EVAL_PERM;
                end

                EVAL_PERM: begin
                    // Split permutation into hour and minute digits
                    integer idx;
                    for (idx = 0; idx < len_h; idx = idx + 1) hour_digits[idx] <= current_perm[idx];
                    for (idx = 0; idx < len_m; idx = idx + 1) minute_digits[idx] <= current_perm[len_h + idx];

                    // Compute hour and minute values
                    hour_value <= compute_value(len_h, hour_digits);
                    minute_value <= compute_value(len_m, minute_digits);

                    // Check if valid
                    if (hour_value < n_reg && minute_value < m_reg) begin
                        count <= count + 32'd1;
                    end

                    state <= NEXT_PERM;
                end

                NEXT_PERM: begin
                    // Find next permutation
                    integer idx;
                    integer temp;
                    integer k;

                    // Find largest index i such that current_perm[i] < current_perm[i+1]
                    i <= 3'd0;
                    for (idx = 0; idx < L - 1; idx = idx + 1) begin
                        if (current_perm[idx] < current_perm[idx + 1]) begin
                            i <= idx;
                        end
                    end

                    // If no such index, all permutations done
                    if (i == 3'd0 && current_perm[0] >= current_perm[1]) begin
                        state <= NEXT_COMB;
                    end else begin
                        // Find largest index j > i such that current_perm[j] > current_perm[i]
                        j <= 3'd0;
                        for (idx = 0; idx < L; idx = idx + 1) begin
                            if (current_perm[idx] > current_perm[i]) begin
                                j <= idx;
                            end
                        end

                        // Swap
                        temp <= current_perm[i];
                        current_perm[i] <= current_perm[j];
                        current_perm[j] <= temp;

                        // Reverse from i+1 to end
                        for (k = 0; k < (L - i - 1) / 2; k = k + 1) begin
                            temp <= current_perm[i + 1 + k];
                            current_perm[i + 1 + k] <= current_perm[L - 1 - k];
                            current_perm[L - 1 - k] <= temp;
                        end

                        state <= EVAL_PERM;
                    end
                end

                NEXT_COMB: begin
                    // Find next combination
                    integer idx;
                    integer t;
                    integer s;

                    // Find rightmost set bit that can be moved left
                    t <= current_bitmask | (current_bitmask - 1);
                    s <= t + 1;
                    current_bitmask <= ((current_bitmask & ~t) / (current_bitmask & -current_bitmask)) | s;

                    // If all combinations done
                    if (popcount(current_bitmask) != L) begin
                        state <= DONE;
                    end else begin
                        state <= INIT_PERM;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= count;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule