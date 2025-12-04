module chemical_element_minimizer(
  input clk, 
  input rst_n, 
  input start, 
  input [4:0] n, 
  input [4:0] m, 
  input [4:0] q, 
  input [31:0] elements [31:0], 
  output reg [5:0] minimal_purchases, 
  output reg done
);
  reg [4:0] parent [0:31];
  reg [4:0] rank [0:31];
  reg [5:0] total_components;
  reg [5:0] cycle;
  
  function automatic [4:0] find_root(input [4:0] idx);
    logic [4:0] current;
    current = idx;
    while (parent[current] != current) begin
      current = parent[current];
    end
    return current;
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0; i<32; i++) parent[i] <= i;
      for (int i=0; i<32; i++) rank[i] <= 0;
      total_components <= 0;
      minimal_purchases <= 0;
      done <= 0;
      cycle <= 6'd34;
    end else begin
      if (start) begin
        for (int i=0; i<32; i++) parent[i] <= (i < (n+m)) ? i[4:0] : parent[i];
        for (int i=0; i<32; i++) rank[i] <= (i < (n+m)) ? 0 : rank[i];
        total_components <= n + m;
        done <= 0;
        cycle <= 0;
      end else if (cycle < 34) begin
        if (cycle < 32) begin
          if (cycle < q) begin
            automatic logic [4:0] row = elements[cycle][9:5];
            automatic logic [4:0] col = elements[cycle][4:0];
            automatic logic [4:0] x_root = find_root(row);
            automatic logic [4:0] y_root = find_root(n + col);
            if (x_root != y_root) begin
              total_components <= total_components - 1;
              if (rank[x_root] > rank[y_root]) parent[y_root] <= x_root;
              else begin
                parent[x_root] <= y_root;
                if (rank[x_root] == rank[y_root]) rank[y_root] <= rank[y_root] + 1;
              end
            end
          end
        end else if (cycle == 32) begin
          minimal_purchases <= total_components - 1;
        end else if (cycle == 33) begin
          done <= 1;
        end
        cycle <= cycle + 1;
      end
    end
  end
endmodule