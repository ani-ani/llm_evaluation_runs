module count_extra_lines(
    input [7:0] warlords,
    input [7:0] num_lines,
    input lines_parallel,
    output reg [7:0] extra_lines
);

// Combinational logic
always @(*) begin
    reg [7:0] max_regions;

    if (num_lines == 8'd0) begin
        max_regions = 8'd1;
    end else if (lines_parallel) begin
        max_regions = 8'd2;
    end else begin
        max_regions = (num_lines >= 8'd255) ? 8'd255 : num_lines + 8'd1;
    end

    if (warlords <= max_regions) begin
        extra_lines = 8'd0;
    end else begin
        extra_lines = warlords - max_regions;
    end
end

endmodule