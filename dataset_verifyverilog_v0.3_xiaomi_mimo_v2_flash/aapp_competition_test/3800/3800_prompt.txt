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

localparam IDLE = 2'b00;
localparam STATE1 = 2'b01;
localparam STATE2 = 2'b10;
localparam DONE = 2'b11;

reg [1:0] state, next_state;
reg [4:0] i, j;
reg [7:0] current_sum;
reg [7:0] freq [0:MAX_SUM];
reg [7:0] U;

wire [3:0] digit [0:N-1];
genvar g;
generate
    for (g=0; g<N; g=g+1) begin
        assign digit[g] = s[4*g+:4];
    end
endgenerate

wire [7:0] new_sum = current_sum + digit[j];
wire [31:0] quotient = a / U;
wire [31:0] remainder = a % U;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

always @(*) begin
    case (state)
        IDLE: next_state = start ? STATE1 : IDLE;
        STATE1: 
            if (i < N) begin
                if (j < N) next_state = STATE1;
                else next_state = (i == N-1) ? STATE2 : STATE1;
            end else next_state = STATE2;
        STATE2: 
            if (a == 0) next_state = DONE;
            else if (U <= MAX_SUM) next_state = STATE2;
            else next_state = DONE;
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i <= 0; j <= 0; current_sum <= 0; result <= 0; done <= 0; U <= 0;
        for (integer k=0; k<=MAX_SUM; k=k+1) freq[k] <= 8'b0;
    end else begin
        done <= 0;
        case (state)
            IDLE: if (start) begin
                i <= 0; j <= 0; current_sum <= 0; result <= 0; U <= 0;
                for (integer k=0; k<=MAX_SUM; k=k+1) freq[k] <= 8'b0;
            end
            STATE1: if (i < N) begin
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
            STATE2: if (a == 0) begin
                result <= 2 * freq[0] * TOTAL_SUBSTRINGS - freq[0] * freq[0];
                done <= 1;
            end else if (U <= MAX_SUM) begin
                if (U != 0 && remainder == 0 && quotient <= MAX_SUM)
                    result <= result + freq[U] * freq[quotient];
                U <= U + 1;
            end else done <= 1;
        endcase
    end
end
endmodule