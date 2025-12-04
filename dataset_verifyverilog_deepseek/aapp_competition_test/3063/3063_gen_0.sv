module debt_resolution (
  input [7:0] valid_mask,
  input [2:0] a_id [7:0],
  input [13:0] b_amount [7:0],
  output reg [16:0] total_min
);
  always_comb begin
    total_min = '0;
    for (int i=0; i<8; i++) begin
      if (valid_mask[i]) begin
        reg [2:0] current;
        reg [7:0] visited;
        reg [13:0] min_val;
        reg found;
        reg broken;
        current = a_id[i];
        visited = (8'b1 << i);
        min_val = b_amount[i];
        found = 0;
        broken = 0;
        for (int step=0; step<8; step++) begin
          if (!broken && !found && valid_mask[current]) begin
            if (current == i) begin
              found = 1;
            end else if (visited[current]) begin
              broken = 1;
            end else begin
              visited[current] = 1'b1;
              if (b_amount[current] < min_val) min_val = b_amount[current];
              current = a_id[current];
            end
          end else if (!valid_mask[current]) begin
            broken = 1;
          end
        end
        if (found) begin
          reg [2:0] min_index = 3'd7;
          for (int j=0; j<8; j++) begin
            if (visited[j] && (j < min_index)) min_index = j;
          end
          if (min_index == i) total_min = total_min + min_val;
        end
      end
    end
  end
endmodule