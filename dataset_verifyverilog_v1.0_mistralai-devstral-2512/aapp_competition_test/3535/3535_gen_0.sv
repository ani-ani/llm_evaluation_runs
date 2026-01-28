module SpinStateCounter(
    input clk,
    input rst_n,
    input start,
    input [31:0] N,
    input [31:0] M,
    input [31:0] K,
    input [31:0] y_in,
    input [31:0] x_in,
    input s_in,
    output reg [63:0] result,
    output reg done,
    output reg error
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_EDGES = 3'd1;
    localparam [2:0] CHECK_GRID = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    localparam [31:0] MOD = 32'd1000000007;

    reg [2:0] state, next_state;
    reg [31:0] N_reg, M_reg, K_reg;
    reg [31:0] k_counter;
    reg [63:0] pow_result;
    reg [63:0] temp;
    reg [31:0] i;
    reg valid_A, valid_B;
    reg contradiction;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            error <= 1'b0;
            k_counter <= 32'd0;
            valid_A <= 1'b1;
            valid_B <= 1'b1;
            contradiction <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    N_reg = N;
                    M_reg = M;
                    K_reg = K;
                    k_counter = 32'd0;
                    valid_A = 1'b1;
                    valid_B = 1'b1;
                    contradiction = 1'b0;
                    next_state = CHECK_EDGES;
                end
            end

            CHECK_EDGES: begin
                if (N_reg == 32'd1 || M_reg == 32'd1) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = CHECK_GRID;
                end
            end

            CHECK_GRID: begin
                if (k_counter < K_reg) begin
                    if (valid_A || valid_B) begin
                        reg [31:0] y = y_in;
                        reg [31:0] x = x_in;
                        reg s = s_in;
                        reg [31:0] parity = (y - 32'd1 + x - 32'd1) % 32'd2;
                        reg expected_A = parity;
                        reg expected_B = parity ^ 1'b1;

                        if (valid_A && s != expected_A) begin
                            valid_A = 1'b0;
                        end
                        if (valid_B && s != expected_B) begin
                            valid_B = 1'b0;
                        end
                        if (!valid_A && !valid_B) begin
                            contradiction = 1'b1;
                        end
                    end
                    k_counter = k_counter + 32'd1;
                end else begin
                    next_state = CALCULATE;
                end
            end

            CALCULATE: begin
                if (N_reg == 32'd1 || M_reg == 32'd1) begin
                    reg [63:0] exponent = (N_reg * M_reg) - K_reg;
                    pow_result = 64'd1;
                    temp = 64'd2;
                    for (i = 0; i < 64; i = i + 1) begin
                        if (exponent[i]) begin
                            pow_result = (pow_result * temp) % MOD;
                        end
                        temp = (temp * temp) % MOD;
                    end
                    result = pow_result;
                end else begin
                    if (contradiction) begin
                        result = 64'd0;
                        error = 1'b1;
                    end else begin
                        result = (valid_A ? 64'd1 : 64'd0) + (valid_B ? 64'd1 : 64'd0);
                    end
                end
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule