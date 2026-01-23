module problem_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [63:0] s,
    output reg [31:0] result,
    output reg done
);

    parameter N = 16;
    parameter MAX_SUM = 9*N;
    localparam TOTAL_SUBSTRINGS = N*(N+1)/2;

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] STATE1 = 2'd1;
    localparam [1:0] STATE2 = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state, next_state;
    reg [4:0] i, j;
    reg [7:0] current_sum;
    reg [7:0] freq [0:MAX_SUM];
    reg [7:0] U;

    wire [3:0] digit [0:N-1];
    generate
        genvar g;
        for (g = 0; g < N; g = g + 1) begin : digit_extraction
            assign digit[g] = s[4*g +: 4];
        end
    endgenerate

    wire [7:0] new_sum;
    wire [31:0] quotient;
    wire [31:0] remainder;

    assign new_sum = current_sum + digit[j];
    assign quotient = a / U;
    assign remainder = a % U;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                next_state = start ? STATE1 : IDLE;
            end
            STATE1: begin
                if (i < N) begin
                    if (j < N) begin
                        next_state = STATE1;
                    end else begin
                        next_state = (i == N - 1) ? STATE2 : STATE1;
                    end
                end else begin
                    next_state = STATE2;
                end
            end
            STATE2: begin
                if (a == 0) begin
                    next_state = DONE;
                end else if (U <= MAX_SUM) begin
                    next_state = STATE2;
                end else begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            j <= 0;
            current_sum <= 0;
            result <= 0;
            done <= 0;
            U <= 0;
            for (integer k = 0; k <= MAX_SUM; k = k + 1) begin
                freq[k] <= 8'd0;
            end
        end else begin
            done <= 0;
            case (state)
                IDLE: begin
                    if (start) begin
                        i <= 0;
                        j <= 0;
                        current_sum <= 0;
                        result <= 0;
                        U <= 0;
                        for (integer k = 0; k <= MAX_SUM; k = k + 1) begin
                            freq[k] <= 8'd0;
                        end
                    end
                end
                STATE1: begin
                    if (i < N) begin
                        if (j < N) begin
                            freq[new_sum] <= freq[new_sum] + 1;
                            current_sum <= new_sum;
                            j <= j + 1;
                        end else begin
                            i <= i + 1;
                            j <= i + 1;
                            current_sum <= 0;
                        end
                    end
                end
                STATE2: begin
                    if (a == 0) begin
                        result <= 2 * freq[0] * TOTAL_SUBSTRINGS - freq[0] * freq[0];
                        done <= 1;
                    end else if (U <= MAX_SUM) begin
                        if (U != 0 && remainder == 0 && quotient <= MAX_SUM) begin
                            result <= result + freq[U] * freq[quotient];
                        end
                        U <= U + 1;
                    end else begin
                        done <= 1;
                    end
                end
            endcase
        end
    end
endmodule