module bug_fixing_dp (
    input clk,
    input rst_n,
    input start,
    input [5:0] bug_severity_0, bug_severity_1, bug_severity_2, bug_severity_3,
    input [3:0] bug_prob_initial_0, bug_prob_initial_1, bug_prob_initial_2, bug_prob_initial_3,
    input [3:0] f_factor,
    input [3:0] num_bugs,
    input [4:0] num_hours,
    output reg [15:0] result,
    output reg done
);

localparam integer IDLE = 0, LOAD = 1, COMPUTE = 2, DONE = 3;

reg [2:0] state;
reg [4:0] num_hours_reg;
reg [3:0] num_bugs_reg;
reg [3:0] f_factor_reg;
reg [5:0] bug_severity_reg [4];
reg [3:0] bug_prob_initial_reg [4];
reg [15:0] result;
reg done;

function [15:0] prob_to_fixed;
input [3:0] index;
begin
    case (index)
        0: prob_to_fixed = 0;
        1: prob_to_fixed = 17;
        2: prob_to_fixed = 34;
        3: prob_to_fixed = 51;
        4: prob_to_fixed = 68;
        5: prob_to_fixed = 85;
        6: prob_to_fixed = 102;
        7: prob_to_fixed = 119;
        8: prob_to_fixed = 136;
        9: prob_to_fixed = 153;
        10: prob_to_fixed = 170;
        11: prob_to_fixed = 187;
        12: prob_to_fixed = 204;
        13: prob_to_fixed = 221;
        14: prob_to_fixed = 238;
        15: prob_to_fixed = 256;
        default: prob_to_fixed =0;
    endcase
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        num_hours_reg <= 0;
        num_bugs_reg <= 0;
        f_factor_reg <= 0;
        bug_severity_reg[0] <= 0;
        bug_severity_reg[1] <= 0;
        bug_severity_reg[2] <= 0;
        bug_severity_reg[3] <= 0;
        bug_prob_initial_reg[0] <= 0;
        bug_prob_initial_reg[1] <= 0;
        bug_prob_initial_reg[2] <= 0;
        bug_prob_initial_reg[3] <= 0;
        result <= 0;
        done <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD;
                else state <= IDLE;
            end
            LOAD: begin
                num_hours_reg <= num_hours;
                num_bugs_reg <= num_bugs;
                f_factor_reg <= f_factor;
                bug_severity_reg[0] <= bug_severity_0;
                bug_severity_reg[1] <= bug_severity_1;
                bug_severity_reg[2] <= bug_severity_2;
                bug_severity_reg[3] <= bug_severity_3;
                bug_prob_initial_reg[0] <= bug_prob_initial_0;
                bug_prob_initial_reg[1] <= bug_prob_initial_1;
                bug_prob_initial_reg[2] <= bug_prob_initial_2;
                bug_prob_initial_reg[3] <= bug_prob_initial_3;
                state <= COMPUTE;
            end
            COMPUTE: begin
                state <= DONE;
            end
            DONE: begin
                done <= 1;
                state <= DONE;
            end
        endcase
    end
end
endmodule