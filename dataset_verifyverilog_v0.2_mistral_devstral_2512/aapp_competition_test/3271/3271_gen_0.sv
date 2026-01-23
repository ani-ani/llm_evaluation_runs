module inversion_counter (
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    input [7:0] C,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'h3B9ACA07;
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE = 3'b100;

    // State machine
    reg [2:0] state = IDLE;

    // DP buffers (only need previous and current row)
    reg [31:0] dp_prev [0:255];
    reg [31:0] dp_curr [0:255];

    // Counters for n and c
    reg [4:0] n = 0;
    reg [8:0] c = 0;

    // Accumulator for sum
    reg [31:0] sum = 0;

    // Sub-state for accumulation
    reg [3:0] i = 0;
    reg [2:0] sub_state = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            n <= 0;
            c <= 0;
            i <= 0;
            sub_state <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize dp_prev[0] = 1, others = 0
                    dp_prev[0] <= 1;
                    for (integer j = 1; j <= 255; j = j + 1) begin
                        dp_prev[j] <= 0;
                    end
                    state <= COMPUTE;
                    n <= 1;
                    c <= 0;
                    i <= 0;
                    sub_state <= 0;
                end

                COMPUTE: begin
                    case (sub_state)
                        0: begin // Start new c
                            sum <= 0;
                            i <= 0;
                            sub_state <= 1;
                        end
                        1: begin // Accumulate sum
                            if (i <= c && i < n) begin
                                sum <= (sum + dp_prev[c - i]) % MOD;
                                i <= i + 1;
                            end else begin
                                dp_curr[c] <= sum;
                                if (c == C) begin
                                    c <= 0;
                                    // Swap buffers
                                    for (integer j = 0; j <= 255; j = j + 1) begin
                                        dp_prev[j] <= dp_curr[j];
                                    end
                                    if (n == N) begin
                                        state <= DONE;
                                        result <= dp_prev[C];
                                        done <= 1;
                                    end else begin
                                        n <= n + 1;
                                    end
                                end else begin
                                    c <= c + 1;
                                end
                                sub_state <= 0;
                            end
                        end
                    endcase
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule