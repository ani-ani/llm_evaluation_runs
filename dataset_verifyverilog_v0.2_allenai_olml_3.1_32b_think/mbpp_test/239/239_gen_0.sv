module sequence_counter(
    input clk,
    input rst_n,
    input start,
    input [4:0] m,
    input [2:0] n,
    output reg [15:0] result,
    output reg done
);

    parameter M = 16;
    parameter N = 4;
    reg [15:0] T[M+1][N+1];
    reg [4:0] i_counter;
    reg [2:0] j_counter;
    reg [15:0] result_reg;
    reg done_reg;
    reg [6:0] cycle_count;
    reg [2:0] state;

    localparam IDLE = 0;
    localparam INIT = 1;
    localparam COMPUTE = 2;
    localparam WAIT = 3;
    localparam DONE = 4;

    always @(posedge clk) begin
        if (!rst_n) begin
            T <= 0;
            i_counter <= 1;
            j_counter <= 1;
            cycle_count <= 0;
            state <= IDLE;
            result_reg <= 0;
            done_reg <= 0;
        end else begin
            if (state == IDLE) begin
                if (start) state <= INIT;
            end else if (state == INIT) begin
                if (j_counter > N || i_counter > M) begin
                    state <= WAIT;
                    result_reg <= T[M][N];
                end else begin
                    if (j_counter == 1) T[i_counter][j_counter] <= i_counter;
                    else T[i_counter][j_counter] <= T[i_counter-1][j_counter] + T[i_counter>>1][j_counter-1];
                    i_counter <= i_counter + 1;
                    if (i_counter > M) begin
                        i_counter <= 1;
                        j_counter <= j_counter + 1;
                    end
                end
            end else if (state == WAIT) begin
                cycle_count <= cycle_count + 1;
                if (cycle_count == 56) begin
                    done_reg <= 1;
                    state <= DONE;
                end
            end
        end
    end

    assign result = result_reg;
    assign done = done_reg;

endmodule