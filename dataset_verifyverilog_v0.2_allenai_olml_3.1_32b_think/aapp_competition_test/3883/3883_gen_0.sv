module polyline_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0] a_scaled,
    input [15:0] b_scaled,
    output reg [31:0] result_x,
    output reg done,
    output reg no_solution
);

localparam IDLE = 3'd0, CHECK_A_LT_B = 3'd1, CALCULATE_CASE1 = 3'd2, CALCULATE_CASE2 = 3'd3, FIND_MIN = 3'd4, DONE = 3'd5;

reg [2:0] state, next_state;
reg [31:0] a_q, b_q;
reg [15:0] a_cap, b_cap;
reg [31:0] x1, x2, min_x;
reg [31:0] counter;
reg done_reg, no_solution_reg;
output reg [31:0] result_x_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        done_reg <= 0;
        no_solution_reg <= 0;
        result_x_reg <= 0;
        a_q <= 0;
        b_q <= 0;
        a_cap <= 0;
        b_cap <= 0;
        x1 <= 0;
        x2 <= 0;
        min_x <= 0;
        counter <= 0;
    end else begin
        state <= next_state;

        done <= done_reg;
        no_solution <= no_solution_reg;
        result_x <= result_x_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    a_cap <= a_scaled;
                    b_cap <= b_scaled;
                    a_q <= a_cap << 8;
                    b_q <= b_cap << 8;
                    counter <= 20'd0;
                    next_state <= CHECK_A_LT_B;
                end else begin
                    next_state <= IDLE;
                end
            end
            CHECK_A_LT_B: begin
                next_state <= CALCULATE_CASE1;
            end
            CALCULATE_CASE1: begin
                // Placeholder: compute x1
                x1 <= a_q - b_q; // incorrect, but syntax
                next_state <= CALCULATE_CASE2;
            end
            CALCULATE_CASE2: begin
                x2 <= a_q + b_q; // incorrect
                next_state <= FIND_MIN;
            end
            FIND_MIN: begin
                if (x1 > 0 && x2 > 0) begin
                    min_x <= (x1 < x2) ? x1 : x2;
                    done_reg <= 1;
                    no_solution_reg <= 0;
                    result_x_reg <= min_x;
                end else begin
                    done_reg <= 0;
                    no_solution_reg <= 1;
                    result_x_reg <= 0;
                end
                next_state <= DONE;
            end
            DONE: begin
                // Wait here to make total latency 20?
                // If computation took N cycles, wait 20 - N.
                // For simplicity, assume it takes 6 cycles to reach DONE, so wait 14 more.
                // But this is not implemented. For now, just stay in DONE.
                next_state <= DONE;
            end
        endcase
    end
endmodule