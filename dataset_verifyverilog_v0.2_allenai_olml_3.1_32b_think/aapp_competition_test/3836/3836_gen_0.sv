module debate_selection (
input clk,
input rst_n,
input start,
input [2:0] count_00, count_01, count_10, count_11,
input [7:0] inf_00_0, inf_00_1, inf_00_2, inf_00_3, inf_00_4, inf_00_5, inf_00_6, inf_00_7,
input [7:0] inf_01_0, inf_01_1, inf_01_2, inf_01_3, inf_01_4, inf_01_5, inf_01_6, inf_01_7,
input [7:0] inf_10_0, inf_10_1, inf_10_2, inf_10_3, inf_10_4, inf_10_5, inf_10_6, inf_10_7,
input [7:0] inf_11_0, inf_11_1, inf_11_2, inf_11_3, inf_11_4, inf_11_5, inf_11_6, inf_11_7,
output reg [15:0] result,
output reg done,
output reg valid);

reg [15:0] total_influence;
reg [31:0] a, b, m;
reg [2:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        total_influence <= 0;
        done <= 0;
        valid <= 0;
        a <= 0;
        b <= 0;
        m <= 0;
    end else begin
        case (state)
            0: begin
                if (start) state <= 1;
            end
            1: begin
                state <= 2;
            end
            2: begin
                if (count_11 > 0) begin
                    a <= count_11;
                    b <= count_11;
                    m <= count_11;
                    if (2*a >= m && 2*b >= m) begin
                        valid <= 1;
                        result <= 0;
                        done <= 1;
                        state <= 3;
                    end else begin
                        state <= 3;
                    end
                end else begin
                    state <= 3;
                end
            end
            3: begin
                done <= 1;
                valid <= 0;
                state <= 3;
            end
        endcase
    end
end

endmodule