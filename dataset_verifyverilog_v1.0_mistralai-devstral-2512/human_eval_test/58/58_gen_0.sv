module SortedUniqueCommonElements(
    input clk,
    input rst_n,
    input start,
    input [7:0] list1 [0:15],
    input [7:0] list2 [0:15],
    input [4:0] len1,
    input [4:0] len2,
    output reg [7:0] result [0:15],
    output reg [4:0] result_len,
    output reg done
);

    localparam [3:0] MAX_SIZE = 4'd16;
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SORT1    = 3'd1;
    localparam [2:0] SORT2    = 3'd2;
    localparam [2:0] INTERSECT = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;

    reg [2:0] state, next_state;
    reg [4:0] i, j, k, m, n;
    reg [7:0] temp;
    reg [7:0] sorted1 [0:15];
    reg [7:0] sorted2 [0:15];
    reg [7:0] common [0:15];
    reg [4:0] common_len;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 5'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < MAX_SIZE; i = i + 1) begin
                result[i] <= 8'd0;
                sorted1[i] <= 8'd0;
                sorted2[i] <= 8'd0;
                common[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                result_len = 5'd0;
                if (start) begin
                    next_state = SORT1;
                    cycle_count = 8'd0;
                    for (i = 0; i < MAX_SIZE; i = i + 1) begin
                        sorted1[i] = list1[i];
                        sorted2[i] = list2[i];
                    end
                end
            end

            SORT1: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end else begin
                    for (i = 1; i < len1; i = i + 1) begin
                        temp = sorted1[i];
                        j = i - 1;
                        while (j >= 0 && sorted1[j] > temp) begin
                            sorted1[j + 1] = sorted1[j];
                            j = j - 1;
                        end
                        sorted1[j + 1] = temp;
                    end
                    next_state = SORT2;
                end
            end

            SORT2: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end else begin
                    for (i = 1; i < len2; i = i + 1) begin
                        temp = sorted2[i];
                        j = i - 1;
                        while (j >= 0 && sorted2[j] > temp) begin
                            sorted2[j + 1] = sorted2[j];
                            j = j - 1;
                        end
                        sorted2[j + 1] = temp;
                    end
                    next_state = INTERSECT;
                end
            end

            INTERSECT: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end else begin
                    common_len = 5'd0;
                    m = 0;
                    n = 0;
                    while (m < len1 && n < len2) begin
                        if (sorted1[m] == sorted2[n]) begin
                            if (common_len == 0 || common[common_len - 1] != sorted1[m]) begin
                                common[common_len] = sorted1[m];
                                common_len = common_len + 1;
                            end
                            m = m + 1;
                            n = n + 1;
                        end else if (sorted1[m] < sorted2[n]) begin
                            m = m + 1;
                        end else begin
                            n = n + 1;
                        end
                    end
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                done = 1'b1;
                result_len = common_len;
                for (i = 0; i < MAX_SIZE; i = i + 1) begin
                    if (i < common_len)
                        result[i] = common[i];
                    else
                        result[i] = 8'd0;
                end
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule