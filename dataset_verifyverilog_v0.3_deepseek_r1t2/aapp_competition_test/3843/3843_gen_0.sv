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
    localparam [3:0] DONE_ST = 4'd8;

    // Internal registers
    reg [3:0] state, next_state;
    reg [31:0] n_reg, m_reg;
    reg [3:0] len_h, len_m;
    reg [2:0] L;
    reg [6:0] current_bitmask;
    reg [2:0] current_perm [0:6];
    reg [31:0] count;
    reg [2:0] phase;
    reg [2:0] p_i, p_j, p_k, p_l;
    reg signed [2:0] p_temp;
    reg found_i;

    // Helper function: Number of base-7 digits
    function [3:0] compute_len;
        input [31:0] val;
        begin
            if (val == 0) compute_len = 4'd1;
            else if (val < 32'd7) compute_len = 4'd1;
            else if (val < 32'd49) compute_len = 4'd2;
            else if (val < 32'd343) compute_len = 4'd3;
            else if (val < 32'd2401) compute_len = 4'd4;
            else if (val < 32'd16807) compute_len = 4'd5;
            else if (val < 32'd117649) compute_len = 4'd6;
            else if (val < 32'd823543) compute_len = 4'd7;
            else compute_len = 4'd8;
        end
    endfunction

    // Fast popcount for 7-bit mask
    function [3:0] popcount7;
        input [6:0] bits;
        reg [3:0] cnt;
        integer i;
        begin
            cnt = 4'd0;
            for (i = 0; i < 7; i = i + 1) cnt = cnt + bits[i];
            popcount7 = cnt;
        end
    endfunction

    // Count trailing zeros (0-6)
    function [2:0] ctz7;
        input [6:0] bits;
        integer i;
        begin
            ctz7 = 3'd7;
            for (i = 0; i < 7; i = i + 1) begin
                if (bits[i]) begin
                    ctz7 = i;
                    break;
                end
            end
        end
    endfunction

    integer i;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            n_reg <= 32'd0;
            m_reg <= 32'd0;
            len_h <= 4'd0;
            len_m <= 4'd0;
            L <= 3'd0;
            current_bitmask <= 7'd0;
            for (i = 0; i < 7; i = i + 1) current_perm[i] <= 3'd0;
            count <= 32'd0;
            phase <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 32'd0;
                    phase <= 3'd0;
                    if (start) begin
                        n_reg <= n;
                        m_reg <= m;
                        state <= COMPUTE_LEN_H;
                    end
                end

                COMPUTE_LEN_H: begin
                    len_h <= compute_len((n == 32'd1) ? 32'd0 : n - 32'd1);
                    state <= COMPUTE_LEN_M;
                end

                COMPUTE_LEN_M: begin
                    len_m <= compute_len((m == 32'd1) ? 32'd0 : m - 32'd1);
                    state <= CHECK_LEN;
                end

                CHECK_LEN: begin
                    if (len_h + len_m > 4'd7) begin
                        result <= 32'd0;
                        state <= DONE_ST;
                    end else begin
                        L <= len_h + len_m;
                        // Initialize to first combination: L least significant bits set
                        current_bitmask <= (7'd1 << (len_h + len_m)) - 7'd1;
                        state <= INIT_PERM;
                    end
                end

                INIT_PERM: begin
                    // Extract digits from current_bitmask
                    integer idx = 0;
                    for (i = 0; i < 7; i = i + 1) begin
                        if (current_bitmask[i] && (idx < L)) begin
                            current_perm[idx] <= i;
                            idx = idx + 1;
                        end
                    end
                    state <= EVAL_PERM;
                end

                EVAL_PERM: begin
                    reg [20:0] hour_val, minute_val;
                    integer k;
                    hour_val = 21'd0;
                    for (k = 0; k < len_h; k = k + 1) begin
                        hour_val = (hour_val * 7) + current_perm[k];
                    end
                    minute_val = 21'd0;
                    for (k = 0; k < len_m; k = k + 1) begin
                        minute_val = (minute_val * 7) + current_perm[len_h + k];
                    end
                    if ((hour_val < n_reg) && (minute_val < m_reg)) begin
                        count <= count + 32'd1;
                    end
                    state <= NEXT_PERM;
                    phase <= 3'd0;
                end

                NEXT_PERM: begin
                    case (phase)
                        3'd0: begin  // Find the largest i where current_perm[i] < current_perm[i+1]
                            p_i <= L - 3'd2;
                            found_i <= 1'b0;
                            phase <= 3'd1;
                        end
                        3'd1: begin
                            if (p_i >= 0 && current_perm[p_i] >= current_perm[p_i + 1]) begin
                                p_i <= p_i - 1;
                            end else begin
                                if (p_i < 0) begin  // Last permutation
                                    state <= NEXT_COMB;
                                    phase <= 3'd0;
                                end else begin
                                    phase <= 3'd2;  // Found i, find j
                                    p_j <= L - 3'd1;
                                end
                            end
                        end
                        3'd2: begin  // Find the largest j > i with current_perm[j] > current_perm[i]
                            if (current_perm[p_j] <= current_perm[p_i]) begin
                                p_j <= p_j - 1;
                            end else begin
                                p_temp <= current_perm[p_i];
                                current_perm[p_i] <= current_perm[p_j];
                                current_perm[p_j] <= p_temp;
                                p_k <= p_i + 3'd1;
                                p_l <= L - 3'd1;
                                phase <= 3'd3;
                            end
                        end
                        3'd3: begin  // Reverse suffix from i+1 to end
                            if (p_k < p_l) begin
                                p_temp <= current_perm[p_k];
                                current_perm[p_k] <= current_perm[p_l];
                                current_perm[p_l] <= p_temp;
                                p_k <= p_k + 3'd1;
                                p_l <= p_l - 3'd1;
                            end else begin
                                state <= EVAL_PERM; // Next permutation
                                phase <= 3'd0;
                            end
                        end
                        default: phase <= 3'd0;
                    endcase
                end

                NEXT_COMB: begin
                    // Gosper's hack for next combination
                    reg [6:0] u, v, next_mask;
                    u = current_bitmask & (-current_bitmask);
                    v = u + current_bitmask;
                    if (v < 7'd127) begin  // 7'd127 = 2^7 -1
                        next_mask = v | ((v ^ current_bitmask) >> (ctz7(u) + 3'd1));
                        current_bitmask <= next_mask;
                        if (popcount7(next_mask) == L) begin
                            state <= INIT_PERM;
                        end else begin
                            state <= DONE_ST;
                        end
                    end else begin
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    result <= count;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule