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
    output [2:0] result,
    output done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [1:0] N_reg;
    reg [7:0] str_reg [0:3][0:3];
    reg [1:0] len_reg [0:3];
    reg [2:0] dp [0:3];
    reg [2:0] result_reg;
    reg done_reg;
    reg [2:0] state;
    reg [1:0] i_reg, j_reg;
    reg [2:0] dp_temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Prefix-suffix checker module
    module prefix_suffix_checker (
        input [7:0] a0, input [7:0] a1, input [7:0] a2, input [7:0] a3,
        input [1:0] len_a,
        input [7:0] b0, input [7:0] b1, input [7:0] b2, input [7:0] b3,
        input [1:0] len_b,
        output reg prefix_valid,
        output reg suffix_valid
    );
        always @(*) begin
            prefix_valid = 1'b1;
            suffix_valid = 1'b1;
            if (len_a > len_b) begin
                prefix_valid = 1'b0;
                suffix_valid = 1'b0;
            end else begin
                // Prefix check
                if (len_a > 0 && a0 != b0) prefix_valid = 1'b0;
                if (len_a > 1 && a1 != b1) prefix_valid = 1'b0;
                if (len_a > 2 && a2 != b2) prefix_valid = 1'b0;
                if (len_a > 3 && a3 != b3) prefix_valid = 1'b0;
                
                // Suffix check
                if (len_a > 0 && a0 != b0) suffix_valid = 1'b0;
                if (len_a > 1 && a1 != b1) suffix_valid = 1'b0;
                if (len_a > 2 && a2 != b2) suffix_valid = 1'b0;
                if (len_a > 3 && a3 != b3) suffix_valid = 1'b0;
            end
        end
    endmodule

    // Generate combinational comparators for all pairs (j,i)
    wire [0:0] valid_pair [0:3][0:3];
    genvar gi, gj;
    generate
        for (gi=0; gi<4; gi=gi+1) begin: outer
            for (gj=0; gj<4; gj=gj+1) begin: inner
                wire prefix_valid, suffix_valid;
                prefix_suffix_checker u_checker (
                    .a0(str_reg[gj][0]), .a1(str_reg[gj][1]), .a2(str_reg[gj][2]), .a3(str_reg[gj][3]),
                    .len_a(len_reg[gj]),
                    .b0(str_reg[gi][0]), .b1(str_reg[gi][1]), .b2(str_reg[gi][2]), .b3(str_reg[gi][3]),
                    .len_b(len_reg[gi]),
                    .prefix_valid(prefix_valid),
                    .suffix_valid(suffix_valid)
                );
                assign valid_pair[gj][gi] = prefix_valid && suffix_valid;
            end
        end
    endgenerate

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done_reg <= 1'b0;
            result_reg <= 3'd0;
            N_reg <= 2'd0;
            i_reg <= 2'd0;
            j_reg <= 2'd0;
            dp_temp <= 3'd0;
            cycle_count <= 8'd0;
            
            // Initialize string registers
            integer k, m;
            for (k=0; k<4; k=k+1) begin
                for (m=0; m<4; m=m+1) begin
                    str_reg[k][m] <= 8'd0;
                end
                len_reg[k] <= 2'd0;
                dp[k] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Capture input strings and N
                    N_reg <= N;
                    str_reg[0][0] <= str0_char0;
                    str_reg[0][1] <= str0_char1;
                    str_reg[0][2] <= str0_char2;
                    str_reg[0][3] <= str0_char3;
                    len_reg[0] <= len0;
                    str_reg[1][0] <= str1_char0;
                    str_reg[1][1] <= str1_char1;
                    str_reg[1][2] <= str1_char2;
                    str_reg[1][3] <= str1_char3;
                    len_reg[1] <= len1;
                    str_reg[2][0] <= str2_char0;
                    str_reg[2][1] <= str2_char1;
                    str_reg[2][2] <= str2_char2;
                    str_reg[2][3] <= str2_char3;
                    len_reg[2] <= len2;
                    str_reg[3][0] <= str3_char0;
                    str_reg[3][1] <= str3_char1;
                    str_reg[3][2] <= str3_char2;
                    str_reg[3][3] <= str3_char3;
                    len_reg[3] <= len3;
                    
                    // Initialize DP array
                    dp[0] <= 3'd1;
                    dp[1] <= 3'd1;
                    dp[2] <= 3'd1;
                    dp[3] <= 3'd1;
                    
                    state <= COMPUTE;
                    i_reg <= 2'd0;
                    j_reg <= 2'd0;
                    dp_temp <= 3'd1;
                    cycle_count <= 8'd0;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all strings
                    if (i_reg >= N_reg || cycle_count >= MAX_CYCLES) begin
                        state <= FIND_MAX;
                    end else begin
                        // Check if we've processed all previous strings for current i
                        if (j_reg >= i_reg) begin
                            dp[i_reg] <= dp_temp;
                            i_reg <= i_reg + 2'd1;
                            j_reg <= 2'd0;
                            dp_temp <= 3'd1;
                        end else begin
                            // Check if str[j] is prefix and suffix of str[i]
                            if (valid_pair[j_reg][i_reg]) begin
                                if (dp[j_reg] + 3'd1 > dp_temp) begin
                                    dp_temp <= dp[j_reg] + 3'd1;
                                end
                            end
                            j_reg <= j_reg + 2'd1;
                        end
                    end
                end

                FIND_MAX: begin
                    // Find maximum value in dp[0..N_reg-1]
                    result_reg <= 3'd1;
                    integer k;
                    for (k=0; k<4; k=k+1) begin
                        if (k < N_reg && dp[k] > result_reg) begin
                            result_reg <= dp[k];
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done_reg <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign result = result_reg;
    assign done = done_reg;

endmodule