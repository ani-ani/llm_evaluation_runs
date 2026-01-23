module bug_fix_scheduler (input clk, input rst_n, input start, input [7:0] bug_complexity [0:7], input [7:0] student_ability [0:7], input [15:0] student_cost [0:7], input [15:0] budget, output reg [3:0] min_days, output reg [2:0] assignment [0:7], output reg done, output reg feasible);
reg [3:0] min_days_int = 4'd0;
reg [2:0] assignment_int [0:7] = 3'b000;
reg done_int = 1'b0;
reg feasible_int = 1'b0;
reg [2:0] state = 3'b000;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        min_days_int <= 4'd0;
        assignment_int <= 3'b000;
        done_int <= 1'b0;
        feasible_int <= 1'b0;
        state <= 3'b000;
    end else begin
        state <= state;
        if (state == 3'b000) begin
            if (start == 1'b1) state <= 3'b001;
        end
    end
end

assign min_days = min_days_int;
assign assignment = assignment_int;
assign done = done_int;
assign feasible = feasible_int;

endmodule