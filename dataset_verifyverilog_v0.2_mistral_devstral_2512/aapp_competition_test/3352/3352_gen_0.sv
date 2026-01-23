module magic_color_counter (
  input [3:0] flat_tree [255:0],
  input [7:0] query_start_idx,
  input [7:0] query_end_idx,
  input [2:0] num_colors,
  output reg [3:0] magical_count
);

  reg [3:0] color_parity [1:4] = '{4{1'b0}}; // Initialize parity for colors 1-4 to 0
  integer i;
  reg [3:0] current_color;

  always @* begin
    // Reset parity bits
    for (i = 1; i <= 4; i = i + 1) begin
      color_parity[i] = 1'b0;
    end

    // Iterate through the query range
    for (i = query_start_idx; i < query_end_idx; i = i + 1) begin
      current_color = flat_tree[i];
      if (current_color >= 1 && current_color <= 4) begin
        // Toggle parity for the current color
        color_parity[current_color] = ~color_parity[current_color];
      end
    end

    // Count magical colors (those with odd parity)
    magical_count = 0;
    for (i = 1; i <= num_colors; i = i + 1) begin
      if (color_parity[i]) begin
        magical_count = magical_count + 1;
      end
    end
  end

endmodule