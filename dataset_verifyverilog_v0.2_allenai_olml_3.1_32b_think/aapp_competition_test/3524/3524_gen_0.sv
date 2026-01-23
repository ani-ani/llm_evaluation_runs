module interleave_verifier (
    input clk,
    input rst_n,
    input start,
    input [5:0] len_s,
    input [5:0] len_s1,
    input [5:0] len_s2,
    input [7:0] s [15:0],
    input [7:0] s1 [7:0],
    input [7:0] s2 [7:0],
    output reg result,
    output reg done
);

reg [2:0] state;
reg [3:0] current_i, current_j;
reg [8:0][8:0] dp;
reg [5:0] len_s_reg, len_s1_reg, len_s2_reg;
reg [7:0] s_reg [15:0];
reg [7:0] s1_reg;
reg [7:0] s2_reg;
reg lengths_match;
reg [8:0] result_reg;
reg done_reg;

localparam IDLE = 3'b000;
localparam INIT = 3'b001;
localparam PROCESSING_ROW = 3'b010;
localparam PROCESSING_COL = 3'b011;
localparam DONE = 3'b100;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_i <= 0;
        current_j <= 0;
        dp <= 0;
        len_s_reg <= 0;
        len_s1_reg <= 0;
        len_s2_reg <= 0;
        s_reg <= 0;
        s1_reg <= 0;
        s2_reg <= 0;
        lengths_match <= 0;
        result_reg <= 0;
        done_reg <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= INIT;
            end
            INIT: begin
                len_s_reg <= len_s;
                len_s1_reg <= len_s1;
                len_s2_reg <= len_s2;
                s_reg[15] <= s[15]; s_reg[14] <= s[14]; s_reg[13] <= s[13]; s_reg[12] <= s[12]; s_reg[11] <= s[11]; s_reg[10] <= s[10]; s_reg[9] <= s[9]; s_reg[8] <= s[8]; s_reg[7] <= s[7]; s_reg[6] <= s[6]; s_reg[5] <= s[5]; s_reg[4] <= s[4]; s_reg[3] <= s[3]; s_reg[2] <= s[2]; s_reg[1] <= s[1]; s_reg[0] <= s[0];
                s1_reg <= s1;
                s2_reg <= s2;
                lengths_match <= (len_s_reg == len_s1_reg + len_s2_reg);
                dp[0][0] <= 1;
                state <= PROCESSING_ROW;
            end
            PROCESSING_ROW: begin
                current_j <= 0;
                state <= PROCESSING_COL;
            end
            PROCESSING_COL: begin
                if (current_i > len_s1_reg) begin
                    state <= DONE;
                end else if (current_j > len_s2_reg) begin
                    current_i <= current_i + 1;
                    state <= PROCESSING_ROW;
                end else begin
                    dp[current_i][current_j] <=
                        (current_i ==0 && current_j ==0) ? 1 : 0 |
                        (current_i >0 && (current_i + current_j -1 < len_s_reg) && s_reg[current_i + current_j -1] == s1_reg[current_i-1] && dp[current_i-1][current_j]) ? 1 : 0 |
                        (current_j >0 && (current_i + current_j -1 < len_s_reg) && s_reg[current_i + current_j -1] == s2_reg[current_j-1] && dp[current_i][current_j-1]) ? 1 : 0;
                    current_j <= current_j +1;
                end
            end
            DONE: begin
                result_reg <= lengths_match && dp[len_s1_reg][len_s2_reg];
                done_reg <= 1;
            end
        endcase
    end
endmodule

assign result = result_reg;
assign done = done_reg;