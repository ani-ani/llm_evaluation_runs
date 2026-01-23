module bottle_collector (
    input [31:0] ax, ay,
    input [31:0] bx, by,
    input [31:0] tx, ty,
    input [2:0] n,
    input [7:0][31:0] bottle_x,
    input [7:0][31:0] bottle_y,
    output [31:0] min_distance
);

    // Helper function for fixed-point distance calculation
    function [31:0] distance_fixed;
        input [31:0] x1, y1, x2, y2;
        reg [63:0] dx, dy, dx2, dy2, sum;
        reg [31:0] dist;
        begin
            dx = $signed(x2) - $signed(x1);
            dy = $signed(y2) - $signed(y1);
            dx2 = dx * dx;
            dy2 = dy * dy;
            sum = dx2 + dy2;

            // Integer square root approximation (shift-based)
            if (sum == 0) begin
                dist = 0;
            end else begin
                dist = 0;
                for (int i = 31; i >= 0; i = i - 1) begin
                    if ((dist + (1 << i)) * (dist + (1 << i)) <= sum) begin
                        dist = dist + (1 << i);
                    end
                end
            end
            distance_fixed = dist;
        end
    endfunction

    // Helper function to find maximum of two values
    function [31:0] max_val;
        input [31:0] a, b;
        begin
            max_val = (a > b) ? a : b;
        end
    endfunction

    // Calculate base cost: 2 * sum(dist(bin, bottle_i))
    reg [31:0] base_cost = 0;
    integer i;
    always @* begin
        base_cost = 0;
        for (i = 0; i < n; i = i + 1) begin
            base_cost = base_cost + distance_fixed(tx, ty, bottle_x[i], bottle_y[i]);
        end
        base_cost = base_cost << 1; // Multiply by 2
    end

    // Calculate savings for each bottle
    reg [31:0] savings_adil [0:7];
    reg [31:0] savings_bera [0:7];
    reg [31:0] max_savings_single = 0;
    reg [31:0] max_savings_double = 0;
    reg [31:0] best_adil = 0;
    reg [31:0] best_bera = 0;
    reg [31:0] best_pair = 0;

    always @* begin
        // Initialize savings arrays
        for (i = 0; i < 8; i = i + 1) begin
            savings_adil[i] = 0;
            savings_bera[i] = 0;
        end

        // Calculate savings for each bottle
        for (i = 0; i < n; i = i + 1) begin
            savings_adil[i] = distance_fixed(tx, ty, bottle_x[i], bottle_y[i]) - 
                             distance_fixed(ax, ay, bottle_x[i], bottle_y[i]);
            savings_bera[i] = distance_fixed(tx, ty, bottle_x[i], bottle_y[i]) - 
                             distance_fixed(bx, by, bottle_x[i], bottle_y[i]);
        end

        // Find best single savings
        max_savings_single = 0;
        for (i = 0; i < n; i = i + 1) begin
            max_savings_single = max_val(max_savings_single, savings_adil[i]);
            max_savings_single = max_val(max_savings_single, savings_bera[i]);
        end

        // Find best pair of savings (different bottles)
        max_savings_double = 0;
        for (i = 0; i < n; i = i + 1) begin
            for (int j = 0; j < n; j = j + 1) begin
                if (i != j) begin
                    best_pair = savings_adil[i] + savings_bera[j];
                    if (best_pair > max_savings_double) begin
                        max_savings_double = best_pair;
                    end
                end
            end
        end

        // Determine final savings
        if (n == 0) begin
            min_distance = 0;
        end else if (n == 1) begin
            min_distance = base_cost - max_savings_single;
        end else begin
            min_distance = base_cost - max_val(max_savings_single, max_savings_double);
        end
    end

endmodule