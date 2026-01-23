module prime_palindrome_solver (
    input clk,
    input rst_n,
    input start,
    input [13:0] p,
    input [13:0] q,
    output reg [9:0] result,
    output reg done,
    output reg no_solution
);

reg [2:0] state;
localparam IDLE = 3'b000;
localparam SIEVE_INIT = 3'b001;
localparam SIEVE_PROCESS = 3'b010;
localparam CALCULATE_ITER = 3'b011;
localparam FINISHED = 3'b100;

reg [10:0] current_n;
reg [9:0] max_n;
reg done_flag;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_n <= 10'd0;
        max_n <= 9'd0;
        done_flag <= 1'b0;
    end else begin
        case (state)
            IDLE: if (start) state <= SIEVE_INIT;
            SIEVE_INIT: state <= SIEVE_PROCESS;
            SIEVE_PROCESS: state <= CALCULATE_ITER;
            CALCULATE_ITER: begin
                if (current_n == 1023) begin
                    state <= FINISHED;
                    done_flag <= 1'b1;
                end else begin
                    current_n <= current_n + 1;
                end
            end
            FINISHED: state <= FINISHED;
        endcase
    end
end

// Output assignments
assign done = done_flag;
assign result = max_n;
assign no_solution = 1'b0;

endmodule