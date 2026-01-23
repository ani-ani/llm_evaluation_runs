module palindrome_count #(
    parameter N = 4
) (
    input clk,
    input rst_n,
    input start,
    input [N-1:0] S,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_FIRST_HALF = (32'd1 << N) - 32'd1;
    localparam [31:0] TOTAL_POSITIONS = N << 1;  // 2 * N

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1;
    localparam [2:0] SCAN = 3'd2;
    localparam [2:0] UPDATE_COUNT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [N-1:0] first_half;
    reg [4:0] pos;          // position in palindrome (0..2N-1)
    reg [N-1:0] matched;
    reg [31:0] count;
    reg [31:0] result_reg;
    reg done_reg;

    // Combinational logic for current character
    reg char;
    always @(*) begin
        if (pos < N)
            char = first_half[pos];
        else
            char = first_half[2*N-1-pos];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            count <= 32'd0;
            first_half <= 0;
            pos <= 5'd0;
            matched <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                        count <= 32'd0;
                        first_half <= 0;
                    end
                end

                SETUP: begin
                    pos <= 5'd0;
                    matched <= 0;
                    state <= SCAN;
                end

                SCAN: begin
                    if (matched < N && char == S[matched]) begin
                        matched <= matched + 1;
                    end
                    pos <= pos + 1;
                    if (pos == TOTAL_POSITIONS - 1) begin
                        state <= UPDATE_COUNT;
                    end
                end

                UPDATE_COUNT: begin
                    if (matched == N) begin
                        if (count < MOD)
                            count <= count + 1;
                        else
                            count <= 32'd0;  // Should not happen with correct logic
                    end
                    if (first_half == MAX_FIRST_HALF) begin
                        state <= FINISH;
                    end else begin
                        first_half <= first_half + 1;
                        state <= SETUP;
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule