module teleportation (
    input clk,
    input rst_n,
    input start,
    input [1:0] N,
    input [7:0] str0_char0,
    input [7:0] str0_char1,
    input [7:0] str0_char2,
    input [7:0] str0_char3,
    input [1:0] len0,
    input [7:0] str1_char0,
    input [7:0] str1_char1,
    input [7:0] str1_char2,
    input [7:0] str1_char3,
    input [1:0] len1,
    input [7:0] str2_char0,
    input [7:0] str2_char1,
    input [7:0] str2_char2,
    input [7:0] str2_char3,
    input [1:0] len2,
    input [7:0] str3_char0,
    input [7:0] str3_char1,
    input [7:0] str3_char2,
    input [7:0] str3_char3,
    input [1:0] len3,
    output reg [2:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE_START = 3'd2;
    localparam [2:0] COMPUTE_OUTER = 3'd3;
    localparam [2:0] COMPUTE_INNER = 3'd4;
    localparam [2:0] UPDATE_DP = 3'd5;
    localparam [2:0] FIND_MAX = 3'd6;
    localparam [2:0] DONE = 3'd7;

    // Internal registers for storing strings and lengths
    reg [7:0] str_reg_0_0;
    reg [7:0] str_reg_0_1;
    reg [7:0] str_reg_0_2;
    reg [7:0] str_reg_0_3;
    reg [7:0] str_reg_1_0;
    reg [7:0] str_reg_1_1;
    reg [7:0] str_reg_1_2;
    reg [7:0] str_reg_1_3;
    reg [7:0] str_reg_2_0;
    reg [7:0] str_reg_2_1;
    reg [7:0] str_reg_2_2;
    reg [7:0] str_reg_2_3;
    reg [7:0] str_reg_3_0;
    reg [7:0] str_reg_3_1;
    reg [7:0] str_reg_3_2;
    reg [7:0] str_reg_3_3;
    reg [1:0] len_reg_0;
    reg [1:0] len_reg_1;
    reg [1:0] len_reg_2;
    reg [1:0] len_reg_3;
    reg [1:0] N_reg;

    // DP array and control registers
    reg [2:0] dp_0;
    reg [2:0] dp_1;
    reg [2:0] dp_2;
    reg [2:0] dp_3;
    reg [1:0] i_reg;
    reg [1:0] j_reg;
    reg [2:0] dp_temp;
    reg [2:0] state;
    reg [2:0] next_state;

    // Combinational signals for prefix/suffix checks
    wire prefix_valid_0_1, suffix_valid_0_1;
    wire prefix_valid_0_2, suffix_valid_0_2;
    wire prefix_valid_0_3, suffix_valid_0_3;
    wire prefix_valid_1_0, suffix_valid_1_0;
    wire prefix_valid_1_2, suffix_valid_1_2;
    wire prefix_valid_1_3, suffix_valid_1_3;
    wire prefix_valid_2_0, suffix_valid_2_0;
    wire prefix_valid_2_1, suffix_valid_2_1;
    wire prefix_valid_2_3, suffix_valid_2_3;
    wire prefix_valid_3_0, suffix_valid_3_0;
    wire prefix_valid_3_1, suffix_valid_3_1;
    wire prefix_valid_3_2, suffix_valid_3_2;

    // Helper task for prefix/suffix check
    task check_prefix_suffix;
        input [7:0] a0, a1, a2, a3;
        input [1:0] len_a;
        input [7:0] b0, b1, b2, b3;
        input [1:0] len_b;
        output reg p_val;
        output reg s_val;
        integer k;
        reg prefix_ok, suffix_ok;
        begin
            prefix_ok = 1'b1;
            suffix_ok = 1'b1;
            if (len_a > len_b) begin
                prefix_ok = 1'b0;
                suffix_ok = 1'b0;
            end else begin
                // Prefix check
                for (k = 0; k < 4; k = k + 1) begin
                    if (k < len_a) begin
                        if (k == 0 && a0 != b0) prefix_ok = 1'b0;
                        if (k == 1 && a1 != b1) prefix_ok = 1'b0;
                        if (k == 2 && a2 != b2) prefix_ok = 1'b0;
                        if (k == 3 && a3 != b3) prefix_ok = 1'b0;
                    end
                end
                // Suffix check
                for (k = 0; k < 4; k = k + 1) begin
                    if (k < len_a) begin
                        if (k == 0) begin
                            if (a0 != ((len_b == 1) ? b0 : (len_b == 2) ? b1 : (len_b == 3) ? b2 : b3)) suffix_ok = 1'b0;
                        end
                        if (k == 1) begin
                            if (a1 != ((len_b == 2) ? b1 : (len_b == 3) ? b2 : (len_b == 4) ? b3 : 8'd0)) suffix_ok = 1'b0;
                        end
                        if (k == 2) begin
                            if (a2 != ((len_b == 3) ? b2 : (len_b == 4) ? b3 : 8'd0)) suffix_ok = 1'b0;
                        end
                        if (k == 3) begin
                            if (a3 != ((len_b == 4) ? b3 : 8'd0)) suffix_ok = 1'b0;
                        end
                    end
                end
            end
            p_val = prefix_ok;
            s_val = suffix_ok;
        end
    endtask

    // Combinational logic for all pairs
    always @(*) begin
        // Check (1,0)
        check_prefix_suffix(
            str_reg_0_0, str_reg_0_1, str_reg_0_2, str_reg_0_3, len_reg_0,
            str_reg_1_0, str_reg_1_1, str_reg_1_2, str_reg_1_3, len_reg_1,
            prefix_valid_1_0, suffix_valid_1_0
        );
        // Check (2,0)
        check_prefix_suffix(
            str_reg_0_0, str_reg_0_1, str_reg_0_2, str_reg_0_3, len_reg_0,
            str_reg_2_0, str_reg_2_1, str_reg_2_2, str_reg_2_3, len_reg_2,
            prefix_valid_2_0, suffix_valid_2_0
        );
        // Check (3,0)
        check_prefix_suffix(
            str_reg_0_0, str_reg_0_1, str_reg_0_2, str_reg_0_3, len_reg_0,
            str_reg_3_0, str_reg_3_1, str_reg_3_2, str_reg_3_3, len_reg_3,
            prefix_valid_3_0, suffix_valid_3_0
        );
        // Check (0,1)
        check_prefix_suffix(
            str_reg_1_0, str_reg_1_1, str_reg_1_2, str_reg_1_3, len_reg_1,
            str_reg_0_0, str_reg_0_1, str_reg_0_2, str_reg_0_3, len_reg_0,
            prefix_valid_0_1, suffix_valid_0_1
        );
        // Check (2,1)
        check_prefix_suffix(
            str_reg_1_0, str_reg_1_1, str_reg_1_2, str_reg_1_3, len_reg_1,
            str_reg_2_0, str_reg_2_1, str_reg_2_2, str_reg_2_3, len_reg_2,
            prefix_valid_2_1, suffix_valid_2_1
        );
        // Check (3,1)
        check_prefix_suffix(
            str_reg_1_0, str_reg_1_1, str_reg_1_2, str_reg_1_3, len_reg_1,
            str_reg_3_0, str_reg_3_1, str_reg_3_2, str_reg_3_3, len_reg_3,
            prefix_valid_3_1, suffix_valid_3_1
        );
        // Check (0,2)
        check_prefix_suffix(
            str_reg_2_0, str_reg_2_1, str_reg_2_2, str_reg_2_3, len_reg_2,
            str_reg_0_0, str_reg_0_1, str_reg_0_2, str_reg_0_3, len_reg_0,
            prefix_valid_0_2, suffix_valid_0_2
        );
        // Check (1,2)
        check_prefix_suffix(
            str_reg_2_0, str_reg_2_1, str_reg_2_2, str_reg_2_3, len_reg_2,
            str_reg_1_0, str_reg_1_1, str_reg_1_2, str_reg_1_3, len_reg_1,
            prefix_valid_1_2, suffix_valid_1_2
        );
        // Check (3,2)
        check_prefix_suffix(
            str_reg_2_0, str_reg_2_1, str_reg_2_2, str_reg_2_3, len_reg_2,
            str_reg_3_0, str_reg_3_1, str_reg_3_2, str_reg_3_3, len_reg_3,
            prefix_valid_3_2, suffix_valid_3_2
        );
        // Check (0,3)
        check_prefix_suffix(
            str_reg_3_0, str_reg_3_1, str_reg_3_2, str_reg_3_3, len_reg_3,
            str_reg_0_0, str_reg_0_1, str_reg_0_2, str_reg_0_3, len_reg_0,
            prefix_valid_0_3, suffix_valid_0_3
        );
        // Check (1,3)
        check_prefix_suffix(
            str_reg_3_0, str_reg_3_1, str_reg_3_2, str_reg_3_3, len_reg_3,
            str_reg_1_0, str_reg_1_1, str_reg_1_2, str_reg_1_3, len_reg_1,
            prefix_valid_1_3, suffix_valid_1_3
        );
        // Check (2,3)
        check_prefix_suffix(
            str_reg_3_0, str_reg_3_1, str_reg_3_2, str_reg_3_3, len_reg_3,
            str_reg_2_0, str_reg_2_1, str_reg_2_2, str_reg_2_3, len_reg_2,
            prefix_valid_2_3, suffix_valid_2_3
        );
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? LOAD : IDLE;
            LOAD: next_state = COMPUTE_START;
            COMPUTE_START: next_state = COMPUTE_OUTER;
            COMPUTE_OUTER: begin
                if (i_reg >= N_reg) next_state = FIND_MAX;
                else next_state = COMPUTE_INNER;
            end
            COMPUTE_INNER: begin
                if (j_reg >= i_reg) next_state = UPDATE_DP;
                else next_state = COMPUTE_INNER;
            end
            UPDATE_DP: next_state = COMPUTE_OUTER;
            FIND_MAX: next_state = DONE;
            DONE: next_state = (start) ? IDLE : DONE;
            default: next_state = IDLE;
        endcase
    end

    // State machine and DP computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 3'd0;
            N_reg <= 2'd0;
            str_reg_0_0 <= 8'd0;
            str_reg_0_1 <= 8'd0;
            str_reg_0_2 <= 8'd0;
            str_reg_0_3 <= 8'd0;
            str_reg_1_0 <= 8'd0;
            str_reg_1_1 <= 8'd0;
            str_reg_1_2 <= 8'd0;
            str_reg_1_3 <= 8'd0;
            str_reg_2_0 <= 8'd0;
            str_reg_2_1 <= 8'd0;
            str_reg_2_2 <= 8'd0;
            str_reg_2_3 <= 8'd0;
            str_reg_3_0 <= 8'd0;
            str_reg_3_1 <= 8'd0;
            str_reg_3_2 <= 8'd0;
            str_reg_3_3 <= 8'd0;
            len_reg_0 <= 2'd0;
            len_reg_1 <= 2'd0;
            len_reg_2 <= 2'd0;
            len_reg_3 <= 2'd0;
            dp_0 <= 3'd0;
            dp_1 <= 3'd0;
            dp_2 <= 3'd0;
            dp_3 <= 3'd0;
            i_reg <= 2'd0;
            j_reg <= 2'd0;
            dp_temp <= 3'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                LOAD: begin
                    N_reg <= N;
                    str_reg_0_0 <= str0_char0;
                    str_reg_0_1 <= str0_char1;
                    str_reg_0_2 <= str0_char2;
                    str_reg_0_3 <= str0_char3;
                    len_reg_0 <= len0;
                    str_reg_1_0 <= str1_char0;
                    str_reg_1_1 <= str1_char1;
                    str_reg_1_2 <= str1_char2;
                    str_reg_1_3 <= str1_char3;
                    len_reg_1 <= len1;
                    str_reg_2_0 <= str2_char0;
                    str_reg_2_1 <= str2_char1;
                    str_reg_2_2 <= str2_char2;
                    str_reg_2_3 <= str2_char3;
                    len_reg_2 <= len2;
                    str_reg_3_0 <= str3_char0;
                    str_reg_3_1 <= str3_char1;
                    str_reg_3_2 <= str3_char2;
                    str_reg_3_3 <= str3_char3;
                    len_reg_3 <= len3;
                end
                COMPUTE_START: begin
                    i_reg <= 2'd0;
                    dp_0 <= 3'd1;
                    dp_1 <= 3'd1;
                    dp_2 <= 3'd1;
                    dp_3 <= 3'd1;
                end
                COMPUTE_OUTER: begin
                    if (i_reg < N_reg) begin
                        j_reg <= 2'd0;
                        dp_temp <= 3'd1;
                    end
                end
                COMPUTE_INNER: begin
                    if (j_reg < i_reg) begin
                        // Check validity based on indices
                        if (j_reg == 2'd0 && i_reg == 2'd1) begin
                            if (prefix_valid_1_0 || suffix_valid_1_0) begin
                                if (dp_0 + 3'd1 > dp_temp) dp_temp <= dp_0 + 3'd1;
                            end
                        end else if (j_reg == 2'd0 && i_reg == 2'd2) begin
                            if (prefix_valid_2_0 || suffix_valid_2_0) begin
                                if (dp_0 + 3'd1 > dp_temp) dp_temp <= dp_0 + 3'd1;
                            end
                        end else if (j_reg == 2'd0 && i_reg == 2'd3) begin
                            if (prefix_valid_3_0 || suffix_valid_3_0) begin
                                if (dp_0 + 3'd1 > dp_temp) dp_temp <= dp_0 + 3'd1;
                            end
                        end else if (j_reg == 2'd1 && i_reg == 2'd2) begin
                            if (prefix_valid_2_1 || suffix_valid_2_1) begin
                                if (dp_1 + 3'd1 > dp_temp) dp_temp <= dp_1 + 3'd1;
                            end
                        end else if (j_reg == 2'd1 && i_reg == 2'd3) begin
                            if (prefix_valid_3_1 || suffix_valid_3_1) begin
                                if (dp_1 + 3'd1 > dp_temp) dp_temp <= dp_1 + 3'd1;
                            end
                        end else if (j_reg == 2'd2 && i_reg == 2'd3) begin
                            if (prefix_valid_3_2 || suffix_valid_3_2) begin
                                if (dp_2 + 3'd1 > dp_temp) dp_temp <= dp_2 + 3'd1;
                            end
                        end
                        j_reg <= j_reg + 2'd1;
                    end
                end
                UPDATE_DP: begin
                    if (i_reg == 2'd0) dp_0 <= dp_temp;
                    else if (i_reg == 2'd1) dp_1 <= dp_temp;
                    else if (i_reg == 2'd2) dp_2 <= dp_temp;
                    else if (i_reg == 2'd3) dp_3 <= dp_temp;
                    i_reg <= i_reg + 2'd1;
                end
                FIND_MAX: begin
                    result <= 3'd1;
                    if (N_reg > 2'd0) begin
                        if (dp_0 > result) result <= dp_0;
                    end
                    if (N_reg > 2'd1) begin
                        if (dp_1 > result) result <= dp_1;
                    end
                    if (N_reg > 2'd2) begin
                        if (dp_2 > result) result <= dp_2;
                    end
                    if (N_reg > 2'd3) begin
                        if (dp_3 > result) result <= dp_3;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule