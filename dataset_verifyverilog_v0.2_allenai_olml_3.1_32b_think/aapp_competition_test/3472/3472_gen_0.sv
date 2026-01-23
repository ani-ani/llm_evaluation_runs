module count_extra_lines(
    input [7:0] warlords,
    input [7:0] num_lines,
    input lines_parallel,
    output reg [7:0] extra_lines
);

// Problem Analysis:
// - We need to determine how many infinite sectors exist given N lines
// - The key insight: L lines can form at most L + 1 infinite regions
//   * If lines are all parallel: 2 regions (both infinite)
//   * If lines intersect: regions = L + 1 (all unbounded when no 3+ concurrent)
// - With N lines, max regions = N + 1 (when at least 2 intersect)
// - We need W warlords to each get 1 infinite region
// - Answer: max(0, W - (N + 1))

// Combinational logic
always @(*) begin
    // Calculate the number of infinite regions available
    // If lines > 0 and not all parallel, regions = lines + 1
    // If lines == 0, regions = 1 (the whole space)
    // If all parallel and lines > 0, regions = 2

    reg [7:0] max_regions;

    if (num_lines == 8'd0) begin
        max_regions = 8'd1;
    end else if (lines_parallel) begin
        max_regions = 8'd2;  // Parallel lines only create 2 regions
    end else begin
        // Intersecting lines create lines + 1 regions
        // Cap at 255 for 8-bit arithmetic
        max_regions = (num_lines >= 8'd255) ? 8'd255 : num_lines + 8'd1;
    end

    // Calculate extra lines needed
    if (warlords <= max_regions) begin
        extra_lines = 8'd0;
    end else begin
        extra_lines = warlords - max_regions;
    end
end

endmodule