module SpectatorSelector(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [1:0] people_type [0:15],
    input [15:0] people_influence [0:15],
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARTITION = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] TAKE_11 = 3'd3;
    localparam [2:0] PAIR_10_01 = 3'd4;
    localparam [2:0] FILL_REMAINDER = 3'd5;
    localparam [2:0] VALIDATE = 3'd6;
    localparam [2:0] OUTPUT = 3'd7;

    reg [2:0] state, next_state;

    // Counters and accumulators
    reg [7:0] count_00, count_01, count_10, count_11;
    reg [7:0] selected_00, selected_01, selected_10, selected_11;
    reg [7:0] total_selected;
    reg [31:0] total_influence;

    // FIFOs for each category (16 elements max)
    reg [15:0] fifo_00 [0:15];
    reg [15:0] fifo_01 [0:15];
    reg [15:0] fifo_10 [0:15];
    reg [15:0] fifo_11 [0:15];

    reg [3:0] fifo_00_ptr, fifo_01_ptr, fifo_10_ptr, fifo_11_ptr;
    reg [3:0] fifo_00_wr, fifo_01_wr, fifo_10_wr, fifo_11_wr;

    // Sorting network control
    reg [3:0] sort_step;
    reg [3:0] sort_category;

    // Bitonic sort implementation for 16 elements
    wire [15:0] bitonic_compare (input [15:0] a, input [15:0] b, input dir);
    assign bitonic_compare = (dir && a < b) || (!dir && a > b) ? b : a;

    // Partition phase
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            count_00 <= 8'd0;
            count_01 <= 8'd0;
            count_10 <= 8'd0;
            count_11 <= 8'd0;
            selected_00 <= 8'd0;
            selected_01 <= 8'd0;
            selected_10 <= 8'd0;
            selected_11 <= 8'd0;
            total_selected <= 8'd0;
            total_influence <= 32'd0;
            fifo_00_ptr <= 4'd0;
            fifo_01_ptr <= 4'd0;
            fifo_10_ptr <= 4'd0;
            fifo_11_ptr <= 4'd0;
            fifo_00_wr <= 4'd0;
            fifo_01_wr <= 4'd0;
            fifo_10_wr <= 4'd0;
            fifo_11_wr <= 4'd0;
            sort_step <= 4'd0;
            sort_category <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 16'd0;

            // Initialize FIFOs
            for (i = 0; i < 16; i = i + 1) begin
                fifo_00[i] <= 16'd0;
                fifo_01[i] <= 16'd0;
                fifo_10[i] <= 16'd0;
                fifo_11[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= PARTITION;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARTITION: begin
                    // Partition inputs into categories
                    for (i = 0; i < N; i = i + 1) begin
                        case (people_type[i])
                            2'd0: begin
                                fifo_00[fifo_00_wr] <= people_influence[i];
                                fifo_00_wr <= fifo_00_wr + 4'd1;
                                count_00 <= count_00 + 8'd1;
                            end
                            2'd1: begin
                                fifo_01[fifo_01_wr] <= people_influence[i];
                                fifo_01_wr <= fifo_01_wr + 4'd1;
                                count_01 <= count_01 + 8'd1;
                            end
                            2'd2: begin
                                fifo_10[fifo_10_wr] <= people_influence[i];
                                fifo_10_wr <= fifo_10_wr + 4'd1;
                                count_10 <= count_10 + 8'd1;
                            end
                            2'd3: begin
                                fifo_11[fifo_11_wr] <= people_influence[i];
                                fifo_11_wr <= fifo_11_wr + 4'd1;
                                count_11 <= count_11 + 8'd1;
                            end
                        endcase
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    // Bitonic sort for each category
                    // This is a simplified version - in practice would need full bitonic network
                    // For synthesis, we'll use a simple bubble sort approach
                    reg [15:0] temp;
                    reg [3:0] j, k;

                    // Sort fifo_11 (descending)
                    for (j = 0; j < count_11 - 1; j = j + 1) begin
                        for (k = 0; k < count_11 - j - 1; k = k + 1) begin
                            if (fifo_11[k] < fifo_11[k + 1]) begin
                                temp <= fifo_11[k];
                                fifo_11[k] <= fifo_11[k + 1];
                                fifo_11[k + 1] <= temp;
                            end
                        end
                    end

                    // Sort fifo_10 (descending)
                    for (j = 0; j < count_10 - 1; j = j + 1) begin
                        for (k = 0; k < count_10 - j - 1; k = k + 1) begin
                            if (fifo_10[k] < fifo_10[k + 1]) begin
                                temp <= fifo_10[k];
                                fifo_10[k] <= fifo_10[k + 1];
                                fifo_10[k + 1] <= temp;
                            end
                        end
                    end

                    // Sort fifo_01 (descending)
                    for (j = 0; j < count_01 - 1; j = j + 1) begin
                        for (k = 0; k < count_01 - j - 1; k = k + 1) begin
                            if (fifo_01[k] < fifo_01[k + 1]) begin
                                temp <= fifo_01[k];
                                fifo_01[k] <= fifo_01[k + 1];
                                fifo_01[k + 1] <= temp;
                            end
                        end
                    end

                    // Sort fifo_00 (descending)
                    for (j = 0; j < count_00 - 1; j = j + 1) begin
                        for (k = 0; k < count_00 - j - 1; k = k + 1) begin
                            if (fifo_00[k] < fifo_00[k + 1]) begin
                                temp <= fifo_00[k];
                                fifo_00[k] <= fifo_00[k + 1];
                                fifo_00[k + 1] <= temp;
                            end
                        end
                    end

                    next_state <= TAKE_11;
                end

                TAKE_11: begin
                    // Take all 11 supporters
                    for (i = 0; i < count_11; i = i + 1) begin
                        total_influence <= total_influence + {16'd0, fifo_11[i]};
                        selected_11 <= selected_11 + 8'd1;
                        total_selected <= total_selected + 8'd1;
                    end
                    next_state <= PAIR_10_01;
                end

                PAIR_10_01: begin
                    // Pair 10 and 01 supporters
                    reg [7:0] pairs;
                    pairs = count_10 < count_01 ? count_10 : count_01;

                    for (i = 0; i < pairs; i = i + 1) begin
                        total_influence <= total_influence + {16'd0, fifo_10[i]};
                        total_influence <= total_influence + {16'd0, fifo_01[i]};
                        selected_10 <= selected_10 + 8'd1;
                        selected_01 <= selected_01 + 8'd1;
                        total_selected <= total_selected + 8'd2;
                    end
                    next_state <= FILL_REMAINDER;
                end

                FILL_REMAINDER: begin
                    // Fill remainder with highest influence from remaining
                    reg [7:0] remaining;
                    remaining = N - total_selected;

                    // Take remaining 10s
                    for (i = selected_10; i < count_10 && total_selected < N; i = i + 1) begin
                        total_influence <= total_influence + {16'd0, fifo_10[i]};
                        selected_10 <= selected_10 + 8'd1;
                        total_selected <= total_selected + 8'd1;
                    end

                    // Take remaining 01s
                    for (i = selected_01; i < count_01 && total_selected < N; i = i + 1) begin
                        total_influence <= total_influence + {16'd0, fifo_01[i]};
                        selected_01 <= selected_01 + 8'd1;
                        total_selected <= total_selected + 8'd1;
                    end

                    // Take remaining 00s
                    for (i = 0; i < count_00 && total_selected < N; i = i + 1) begin
                        total_influence <= total_influence + {16'd0, fifo_00[i]};
                        selected_00 <= selected_00 + 8'd1;
                        total_selected <= total_selected + 8'd1;
                    end

                    next_state <= VALIDATE;
                end

                VALIDATE: begin
                    // Check constraints: 2*a >= m and 2*b >= m
                    reg [7:0] a, b, m;
                    a = selected_11 + selected_10;
                    b = selected_11 + selected_01;
                    m = total_selected;

                    if ((2*a >= m) && (2*b >= m) && m > 0) begin
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    // Output result (scale down from Q16.16)
                    result <= total_influence[31:16];
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            state <= next_state;
        end
    end

endmodule