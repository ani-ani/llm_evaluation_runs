module PermutationSubsequenceFinder(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [3:0] p,
    input [5:0] a [0:15],
    input [5:0] b [0:15],
    output reg [3:0] result_count,
    output reg [3:0] result_positions [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] EXTRACT = 3'd1;
    localparam [2:0] BUILD_HIST = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] SLIDE = 3'd4;
    localparam [2:0] RECORD = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;
    reg [3:0] q_reg, q_next;
    reg [3:0] i_reg, i_next;
    reg [3:0] c_length;
    reg [5:0] c [0:15];
    reg [5:0] hist_c [0:63];
    reg [5:0] hist_b [0:63];
    reg [3:0] match_count;
    reg [3:0] result_index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize histograms
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            q_reg <= 4'd0;
            i_reg <= 4'd0;
            c_length <= 4'd0;
            match_count <= 4'd0;
            result_count <= 4'd0;
            result_index <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (j = 0; j < 16; j = j + 1) begin
                result_positions[j] <= 4'd0;
            end
            for (j = 0; j < 64; j = j + 1) begin
                hist_c[j] <= 6'd0;
                hist_b[j] <= 6'd0;
            end
        end else begin
            state <= next_state;
            q_reg <= q_next;
            i_reg <= i_next;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= EXTRACT;
                        q_next <= 4'd0;
                        i_next <= 4'd0;
                        match_count <= 4'd0;
                        result_count <= 4'd0;
                        result_index <= 4'd0;
                        // Initialize hist_b
                        for (j = 0; j < 64; j = j + 1) begin
                            hist_b[j] <= 6'd0;
                        end
                        for (j = 0; j < m; j = j + 1) begin
                            hist_b[b[j]] <= hist_b[b[j]] + 6'd1;
                        end
                    end
                end

                EXTRACT: begin
                    // Extract subsequence c
                    c_length <= 4'd0;
                    for (j = 0; j < 16; j = j + 1) begin
                        if (q_reg + j * p < n) begin
                            c[j] <= a[q_reg + j * p];
                            c_length <= c_length + 4'd1;
                        end else begin
                            c[j] <= 6'd0;
                        end
                    end
                    if (c_length >= m) begin
                        next_state <= BUILD_HIST;
                        i_next <= 4'd0;
                    end else begin
                        next_state <= EXTRACT;
                        q_next <= q_reg + 4'd1;
                        if (q_next >= p) begin
                            next_state <= FINISH;
                        end
                    end
                end

                BUILD_HIST: begin
                    // Build initial histogram for first m elements
                    for (j = 0; j < 64; j = j + 1) begin
                        hist_c[j] <= 6'd0;
                    end
                    for (j = 0; j < m; j = j + 1) begin
                        hist_c[c[j]] <= hist_c[c[j]] + 6'd1;
                    end
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    // Compare histograms
                    reg match;
                    match = 1'b1;
                    for (j = 0; j < 64; j = j + 1) begin
                        if (hist_c[j] != hist_b[j]) begin
                            match = 1'b0;
                        end
                    end
                    if (match) begin
                        next_state <= RECORD;
                    end else if (i_reg + m < c_length) begin
                        next_state <= SLIDE;
                    end else begin
                        next_state <= EXTRACT;
                        q_next <= q_reg + 4'd1;
                        if (q_next >= p) begin
                            next_state <= FINISH;
                        end
                    end
                end

                SLIDE: begin
                    // Slide window: remove c[i], add c[i+m]
                    hist_c[c[i_reg]] <= hist_c[c[i_reg]] - 6'd1;
                    hist_c[c[i_reg + m]] <= hist_c[c[i_reg + m]] + 6'd1;
                    i_next <= i_reg + 4'd1;
                    next_state <= COMPARE;
                end

                RECORD: begin
                    // Record position
                    result_positions[result_index] <= q_reg + 4'd1;
                    result_count <= result_count + 4'd1;
                    result_index <= result_index + 4'd1;
                    match_count <= match_count + 4'd1;
                    if (i_reg + m < c_length) begin
                        next_state <= SLIDE;
                    end else begin
                        next_state <= EXTRACT;
                        q_next <= q_reg + 4'd1;
                        if (q_next >= p) begin
                            next_state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule