module coin_ways_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [31:0] a_1, a_2, a_3,
    input [3:0] b_0, b_1, b_2, b_3,
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

reg [31:0] result;
reg done;
reg [2:0] state;
reg [1:0] coin_idx;
reg [31:0] current_m;
reg [31:0] ways [0:63];

always @(negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'd0;
        result <= 32'd0;
        done <= 1'b0;
        coin_idx <= 2'd0;
        current_m <= 32'd0;
        ways[0] <= 32'd1;
        ways[1] <=32'd0;
        ways[2] <=32'd0;
        ways[3] <=32'd0;
        ways[4] <=32'd0;
        ways[5] <=32'd0;
        ways[6] <=32'd0;
        ways[7] <=32'd0;
        ways[8] <=32'd0;
        ways[9] <=32'd0;
        ways[10] <=32'd0;
        ways[11] <=32'd0;
        ways[12] <=32'd0;
        ways[13] <=32'd0;
        ways[14] <=32'd0;
        ways[15] <=32'd0;
        ways[16] <=32'd0;
        ways[17] <=32'd0;
        ways[18] <=32'd0;
        ways[19] <=32'd0;
        ways[20] <=32'd0;
        ways[21] <=32'd0;
        ways[22] <=32'd0;
        ways[23] <=32'd0;
        ways[24] <=32'd0;
        ways[25] <=32'd0;
        ways[26] <=32'd0;
        ways[27] <=32'd0;
        ways[28] <=32'd0;
        ways[29] <=32'd0;
        ways[30] <=32'd0;
        ways[31] <=32'd0;
        ways[32] <=32'd0;
        ways[33] <=32'd0;
        ways[34] <=32'd0;
        ways[35] <=32'd0;
        ways[36] <=32'd0;
        ways[37] <=32'd0;
        ways[38] <=32'd0;
        ways[39] <=32'd0;
        ways[40] <=32'd0;
        ways[41] <=32'd0;
        ways[42] <=32'd0;
        ways[43] <=32'd0;
        ways[44] <=32'd0;
        ways[45] <=32'd0;
        ways[46] <=32'd0;
        ways[47] <=32'd0;
        ways[48] <=32'd0;
        ways[49] <=32'd0;
        ways[50] <=32'd0;
        ways[51] <=32'd0;
        ways[52] <=32'd0;
        ways[53] <=32'd0;
        ways[54] <=32'd0;
        ways[55] <=32'd0;
        ways[56] <=32'd0;
        ways[57] <=32'd0;
        ways[58] <=32'd0;
        ways[59] <=32'd0;
        ways[60] <=32'd0;
        ways[61] <=32'd0;
        ways[62] <=32'd0;
        ways[63] <=32'd0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        case (state)
            3'd0: begin
                if (start == 1) begin
                    current_m <= m;
                    if (n == 4'd1) begin
                        state <= 3'd3;
                    end else begin
                        coin_idx <= 2'd1;
                        state <= 3'd1;
                    end
                end
            end
            3'd1: begin
                if (coin_idx == 1) begin
                    integer unsigned m_val = (unsigned)current_m;
                    integer unsigned r = m_val % (unsigned)a_1;
                    if (r !=0) begin
                        result <= 32'd0;
                        done <=1'b1;
                        state <=3'd4;
                    end else begin
                        current_m <= m_val / (unsigned)a_1;
                        state <=3'd2;
                    end
                end else if (coin_idx ==2) begin
                    integer unsigned m_val = (unsigned)current_m;
                    integer unsigned r = m_val % (unsigned)a_2;
                    if (r !=0) begin
                        result <= 32'd0;
                        done <=1'b1;
                        state <=3'd4;
                    end else begin
                        current_m <= m_val / (unsigned)a_2;
                        state <=3'd2;
                    end
                end else if (coin_idx ==3) begin
                    integer unsigned m_val = (unsigned)current_m;
                    integer unsigned r = m_val % (unsigned)a_3;
                    if (r !=0) begin
                        result <= 32'd0;
                        done <=1'b1;
                        state <=3'd4;
                    end else begin
                        current_m <= m_val / (unsigned)a_3;
                        state <=3'd2;
                    end
                end
            end
            3'd2: begin
                if (coin_idx < n-1) begin
                    coin_idx <= coin_idx +1;
                    state <=3'd1;
                end else begin
                    state <=3'd3;
                end
            end
            3'd3: begin
                integer b_max;
                if (n ==4'd1) b_max = b_0;
                else if (n ==4'd2) b_max = b_1;
                else if (n ==4'd3) b_max = b_2;
                else if (n ==4'd4) b_max = b_3;
                if (current_m > b_max) begin
                    result <=32'd0;
                end else begin
                    result <=32'd1;
                end
                done <=1'b1;
                state <=3'd4;
            end
            3'd4: begin
                state <=3'd4;
            end
        endcase
    end
end

assign done = done;
assign result = result;

endmodule