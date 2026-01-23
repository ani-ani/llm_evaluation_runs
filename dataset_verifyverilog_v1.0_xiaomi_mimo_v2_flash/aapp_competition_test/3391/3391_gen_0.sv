module HouseZone #(
    parameter N = 4,
    parameter ADDR_WIDTH = 2,
    parameter DATA_WIDTH = 16
)(
    input wire [ADDR_WIDTH-1:0] query_a,
    input wire [ADDR_WIDTH-1:0] query_b,
    input wire signed [DATA_WIDTH-1:0] house_x [0:N-1],
    input wire signed [DATA_WIDTH-1:0] house_y [0:N-1],
    output reg signed [DATA_WIDTH-1:0] result
);

    integer i, j;
    reg signed [DATA_WIDTH-1:0] min_x, max_x, min_y, max_y;
    reg [ADDR_WIDTH-1:0] idx_min_x, idx_max_x, idx_min_y, idx_max_y;
    reg signed [DATA_WIDTH-1:0] L0;
    reg signed [DATA_WIDTH-1:0] L_c;
    reg signed [DATA_WIDTH-1:0] min_x_c, max_x_c, min_y_c, max_y_c;
    reg first;
    reg [ADDR_WIDTH-1:0] c0, c1, c2, c3;
    reg signed [DATA_WIDTH-1:0] diff_x, diff_y;

    always_comb begin
        // Initialize with the first house in the range
        min_x = house_x[query_a];
        max_x = house_x[query_a];
        min_y = house_y[query_a];
        max_y = house_y[query_a];
        idx_min_x = query_a;
        idx_max_x = query_a;
        idx_min_y = query_a;
        idx_max_y = query_a;

        // Find extremes and their indices
        for (i = query_a + 1; i <= query_b; i = i + 1) begin
            if (house_x[i] < min_x) begin
                min_x = house_x[i];
                idx_min_x = i;
            end
            if (house_x[i] > max_x) begin
                max_x = house_x[i];
                idx_max_x = i;
            end
            if (house_y[i] < min_y) begin
                min_y = house_y[i];
                idx_min_y = i;
            end
            if (house_y[i] > max_y) begin
                max_y = house_y[i];
                idx_max_y = i;
            end
        end

        // Compute L0
        diff_x = max_x - min_x;
        diff_y = max_y - min_y;
        L0 = (diff_x > diff_y) ? diff_x : diff_y;
        result = L0;

        // Candidate indices
        c0 = idx_min_x;
        c1 = idx_max_x;
        c2 = idx_min_y;
        c3 = idx_max_y;

        // Candidate 0: remove idx_min_x
        first = 1;
        for (j = query_a; j <= query_b; j = j + 1) begin
            if (j != c0) begin
                if (first) begin
                    min_x_c = house_x[j];
                    max_x_c = house_x[j];
                    min_y_c = house_y[j];
                    max_y_c = house_y[j];
                    first = 0;
                end else begin
                    if (house_x[j] < min_x_c) min_x_c = house_x[j];
                    if (house_x[j] > max_x_c) max_x_c = house_x[j];
                    if (house_y[j] < min_y_c) min_y_c = house_y[j];
                    if (house_y[j] > max_y_c) max_y_c = house_y[j];
                end
            end
        end
        if (!first) begin
            diff_x = max_x_c - min_x_c;
            diff_y = max_y_c - min_y_c;
            L_c = (diff_x > diff_y) ? diff_x : diff_y;
            if (L_c < result) result = L_c;
        end

        // Candidate 1: remove idx_max_x, if different from c0
        if (c1 != c0) begin
            first = 1;
            for (j = query_a; j <= query_b; j = j + 1) begin
                if (j != c1) begin
                    if (first) begin
                        min_x_c = house_x[j];
                        max_x_c = house_x[j];
                        min_y_c = house_y[j];
                        max_y_c = house_y[j];
                        first = 0;
                    end else begin
                        if (house_x[j] < min_x_c) min_x_c = house_x[j];
                        if (house_x[j] > max_x_c) max_x_c = house_x[j];
                        if (house_y[j] < min_y_c) min_y_c = house_y[j];
                        if (house_y[j] > max_y_c) max_y_c = house_y[j];
                    end
                end
            end
            if (!first) begin
                diff_x = max_x_c - min_x_c;
                diff_y = max_y_c - min_y_c;
                L_c = (diff_x > diff_y) ? diff_x : diff_y;
                if (L_c < result) result = L_c;
            end
        end

        // Candidate 2: remove idx_min_y, if not already considered
        if (c2 != c0 && c2 != c1) begin
            first = 1;
            for (j = query_a; j <= query_b; j = j + 1) begin
                if (j != c2) begin
                    if (first) begin
                        min_x_c = house_x[j];
                        max_x_c = house_x[j];
                        min_y_c = house_y[j];
                        max_y_c = house_y[j];
                        first = 0;
                    end else begin
                        if (house_x[j] < min_x_c) min_x_c = house_x[j];
                        if (house_x[j] > max_x_c) max_x_c = house_x[j];
                        if (house_y[j] < min_y_c) min_y_c = house_y[j];
                        if (house_y[j] > max_y_c) max_y_c = house_y[j];
                    end
                end
            end
            if (!first) begin
                diff_x = max_x_c - min_x_c;
                diff_y = max_y_c - min_y_c;
                L_c = (diff_x > diff_y) ? diff_x : diff_y;
                if (L_c < result) result = L_c;
            end
        end

        // Candidate 3: remove idx_max_y, if not already considered
        if (c3 != c0 && c3 != c1 && c3 != c2) begin
            first = 1;
            for (j = query_a; j <= query_b; j = j + 1) begin
                if (j != c3) begin
                    if (first) begin
                        min_x_c = house_x[j];
                        max_x_c = house_x[j];
                        min_y_c = house_y[j];
                        max_y_c = house_y[j];
                        first = 0;
                    end else begin
                        if (house_x[j] < min_x_c) min_x_c = house_x[j];
                        if (house_x[j] > max_x_c) max_x_c = house_x[j];
                        if (house_y[j] < min_y_c) min_y_c = house_y[j];
                        if (house_y[j] > max_y_c) max_y_c = house_y[j];
                    end
                end
            end
            if (!first) begin
                diff_x = max_x_c - min_x_c;
                diff_y = max_y_c - min_y_c;
                L_c = (diff_x > diff_y) ? diff_x : diff_y;
                if (L_c < result) result = L_c;
            end
        end
    end

endmodule