module traveling_salesman(
  input [3:0] n,
  input [3:0] m,
  input [5:0][5:0] edges,
  output [1:0] min_flights,
  output [3:0] airports
);

  wire [3:0] max_matching_size;
  wire [3:0] unmatched_cities;

  assign max_matching_size = compute_max_matching(n, m, edges);
  assign min_flights = (n - 1) - max_matching_size;
  assign airports = (min_flights == 0) ? 0 : unmatched_cities;

  function [3:0] compute_max_matching;
    input [3:0] n;
    input [3:0] m;
    input [5:0][5:0] edges;
    reg [3:0] max_size;
    reg [3:0] unmatched_mask;
    integer i, j, k;
    reg [5:0] subset;
    reg [3:0] left_nodes;
    reg [3:0] right_nodes;
    reg [3:0] current_size;
    reg [3:0] temp_unmatched;

    begin
      max_size = 0;
      unmatched_mask = 0;

      for (i = 0; i < 64; i = i + 1) begin
        subset = i;
        left_nodes = 0;
        right_nodes = 0;
        current_size = 0;
        temp_unmatched = 0;

        for (j = 0; j < 6; j = j + 1) begin
          if (subset[j]) begin
            if (edges[j][5:4] < n && edges[j][3:2] < n) begin
              if (!left_nodes[edges[j][5:4]] && !right_nodes[edges[j][3:2]]) begin
                left_nodes[edges[j][5:4]] = 1;
                right_nodes[edges[j][3:2]] = 1;
                current_size = current_size + 1;
              end
            end
          end
        end

        if (current_size > max_size) begin
          max_size = current_size;
          unmatched_mask = 0;
          for (k = 0; k < n; k = k + 1) begin
            if (!left_nodes[k] || !right_nodes[k]) begin
              unmatched_mask[k] = 1;
            end
          end
        end else if (current_size == max_size) begin
          for (k = 0; k < n; k = k + 1) begin
            if (!left_nodes[k] || !right_nodes[k]) begin
              unmatched_mask[k] = 1;
            end
          end
        end
      end

      compute_max_matching = max_size;
    end
  endfunction

  assign unmatched_cities = compute_max_matching(n, m, edges);

endmodule