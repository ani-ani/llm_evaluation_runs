module compute_sum #(
    parameter N = 8,
    parameter COLOR_WIDTH = 9,
    parameter SUM_WIDTH = 16
)(
    input clk,
    input rst_n,
    input start,
    input [COLOR_WIDTH-1:0] color [0:N-1][0:N-1],
    output reg [SUM_WIDTH-1:0] sum,
    output reg done
);
    reg [7:0] subset;
    reg [7:0] inner;
    reg [SUM_WIDTH-1:0] total;
    reg [7:0] max_size;
    reg [7:0] pair_i, pair_j;
    reg [COLOR_WIDTH-1:0] first_color;
    reg mono_ok;
    reg [3:0] state;
    localparam [3:0] IDLE = 0;
    localparam [3:0] INIT_OUTER = 1;
    localparam [3:0] INIT_INNER = 2;
    localparam [3:0] CHECK_SUBMASK = 3;
    localparam [3:0] START_MONO = 4;
    localparam [3:0] CHECK_PAIR = 5;
    localparam [3:0] NEXT_PAIR = 6;
    localparam [3:0] UPDATE_MAX = 7;
    localparam [3:0] NEXT_INNER = 8;
    localparam [3:0] ADD_SUM = 9;
    localparam [3:0] NEXT_OUTER = 10;
    localparam [3:0] DONE = 11;

    function [7:0] popcnt;
        input [7:0] mask;
        integer k;
        begin
            popcnt = 0;
            for (k = 0; k < 8; k = k + 1) begin
                if (mask[k]) popcnt = popcnt + 1;
            end
        end
    endfunction

    function is_subset;
        input [7:0] m1;
        input [7:0] m2;
        begin
            is_subset = ((m1 & m2) == m1);
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum <= 0;
            done <= 0;
            subset <= 0;
            inner <= 0;
            total <= 0;
            max_size <= 0;
            pair_i <= 0;
            pair_j <= 0;
            first_color <= 0;
            mono_ok <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INIT_OUTER;
                    end
                end

                INIT_OUTER: begin
                    subset <= 8'd1;
                    total <= 0;
                    state <= INIT_INNER;
                end

                INIT_INNER: begin
                    inner <= 8'd1;
                    max_size <= 8'd1;
                    state <= CHECK_SUBMASK;
                end

                CHECK_SUBMASK: begin
                    if (inner == 8'd0 || inner > 8'hFF) begin
                        state <= ADD_SUM;
                    end else if (is_subset(inner, subset)) begin
                        state <= START_MONO;
                    end else begin
                        state <= NEXT_INNER;
                    end
                end

                START_MONO: begin
                    mono_ok <= 1;
                    first_color <= 0;
                    pair_i <= 0;
                    pair_j <= 1;
                    state <= CHECK_PAIR;
                end

                CHECK_PAIR: begin
                    if (pair_i >= N) begin
                        if (mono_ok) begin
                            state <= UPDATE_MAX;
                        end else begin
                            state <= NEXT_INNER;
                        end
                    end else begin
                        if (inner[pair_i] && inner[pair_j] && (pair_i != pair_j)) begin
                            if (color[pair_i][pair_j] != first_color) begin
                                if (first_color == 0) begin
                                    first_color <= color[pair_i][pair_j];
                                end else begin
                                    mono_ok <= 0;
                                end
                            end
                        end
                        state <= NEXT_PAIR;
                    end
                end

                NEXT_PAIR: begin
                    if (pair_j < N - 1) begin
                        pair_j <= pair_j + 1;
                    end else begin
                        pair_j <= pair_i + 2;
                        pair_i <= pair_i + 1;
                    end
                    state <= CHECK_PAIR;
                end

                UPDATE_MAX: begin
                    if (popcnt(inner) > max_size) begin
                        max_size <= popcnt(inner);
                    end
                    state <= NEXT_INNER;
                end

                NEXT_INNER: begin
                    inner <= inner + 1;
                    state <= CHECK_SUBMASK;
                end

                ADD_SUM: begin
                    total <= total + max_size;
                    state <= NEXT_OUTER;
                end

                NEXT_OUTER: begin
                    subset <= subset + 1;
                    if (subset == 8'd0) begin
                        state <= DONE;
                    end else begin
                        state <= INIT_INNER;
                    end
                end

                DONE: begin
                    sum <= total;
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule