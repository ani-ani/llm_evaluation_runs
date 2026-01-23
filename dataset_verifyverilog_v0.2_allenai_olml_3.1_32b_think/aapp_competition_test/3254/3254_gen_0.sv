module average_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] target_avg_q16,
    output reg [7:0] count_ones,
    output reg [7:0] count_twos,
    output reg [7:0] count_threes,
    output reg [7:0] count_fours,
    output reg [7:0] count_fives,
    output reg [7:0] total_count,
    output reg done,
    output reg found
);

reg [2:0] state;
reg [4:0] current_total;
reg [4:0] c1, c2, c3, c4;
reg [7:0] solution_c1, solution_c2, solution_c3, solution_c4, solution_c5;
reg [7:0] solution_total;
reg solution_found;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'b0;
        current_total <= 5'b1;
        c1 <=5'b0; c2<=5'b0; c3<=5'b0; c4<=5'b0;
        solution_c1 <=8'b0; solution_c2<=8'b0; solution_c3<=8'b0; solution_c4<=8'b0; solution_c5<=8'b0; solution_total<=8'b0;
        solution_found <=1'b0;
        count_ones <=8'b0; count_twos<=8'b0; count_threes<=8'b0; count_fours<=8'b0; count_fives<=8'b0; total_count<=8'b0; done<=1'b0; found<=1'b0;
    end else begin
        case (state)
            3'b0: // IDLE
                if (start) state <= 3'b1;
            3'b1: // INIT
                state <= 3'b2;
            3'b2: // SEARCH
                if ( ( (c1 + 2*c2 + 3*c3 +4*c4 +5*(current_total - c1 - c2 - c3 - c4)) << 16 ) == (target_avg_q16 * current_total) ) begin
                    solution_c1 <= c1;
                    solution_c2 <= c2;
                    solution_c3 <= c3;
                    solution_c4 <= c4;
                    solution_c5 <= current_total - c1 - c2 - c3 - c4;
                    solution_total <= current_total;
                    solution_found <=1'b1;
                    state <= 3'b3;
                end else begin
                    if (c4 < (current_total - c1 - c2 - c3)) begin
                        c4 <= c4 +1;
                    end else begin
                        c4 <=5'b0;
                        if (c3 < (current_total - c1 - c2)) begin
                            c3 <= c3 +1;
                        end else begin
                            c3 <=5'b0;
                            if (c2 < (current_total - c1)) begin
                                c2 <= c2 +1;
                            end else begin
                                c2 <=5'b0;
                                if (c1 < current_total) begin
                                    c1 <= c1 +1;
                                end else begin
                                    if (current_total < 16) begin
                                        current_total <= current_total +1;
                                        c1 <=5'b0; c2<=5'b0; c3<=5'b0; c4<=5'b0;
                                    end else begin
                                        state <= 3'b3;
                                        solution_found <=1'b0;
                                    end
                                end
                            end
                        end
                    end
                end
            3'b3: // DONE
                state <=3'b3;
        endcase
        if (state == 3'b3) begin
            if (solution_found) begin
                count_ones <= solution_c1;
                count_twos <= solution_c2;
                count_threes <= solution_c3;
                count_fours <= solution_c4;
                count_fives <= solution_c5;
                total_count <= solution_total;
                found <=1'b1;
                done <=1'b1;
            end else begin
                count_ones <=8'b0; count_twos <=8'b0; count_threes <=8'b0; count_fours <=8'b0; count_fives <=8'b0;
                total_count <=8'b0;
                found <=1'b0;
                done <=1'b1;
            end
        end else begin
            done <=1'b0;
            found <=1'b0;
            count_ones <=8'b0; count_twos <=8'b0; count_threes <=8'b0; count_fours <=8'b0; count_fives <=8'b0; total_count<=8'b0;
        end
    end
endmodule