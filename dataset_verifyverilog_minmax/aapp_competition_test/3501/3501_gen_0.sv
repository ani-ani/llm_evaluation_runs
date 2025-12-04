module camel_order_verifier(
  input reg [2:0] n,
  input reg [23:0] jaap_bet,
  input reg [23:0] jan_bet,
  input reg [23:0] thijs_bet,
  output reg [4:0] count
);
  // Internal variables
  logic [3:0] pos_jaap[8];
  logic [3:0] pos_jan[8];
  logic [3:0] pos_thijs[8];
  // Combinational logic
  always @* begin
    int n_int = n; // Convert n to integer for loop bounds
    logic [2:0] cam; // temporary for extracting camel id (0‑7)
    // Initialize position tables (default 8 = not found)
    for (int i = 0; i < 8; i++) begin
      pos_jaap[i] = 4'd8;
      pos_jan[i] = 4'd8;
      pos_thijs[i] = 4'd8;
    end
    // Fill position tables using the first n entries of each bet
    for (int i = 0; i < 8; i++) begin
      if (i < n_int) begin
        // Extract the 3‑bit field for the i‑th camel in the bet
        cam = (jaap_bet >> (21 - 3*i)) & 7;
        pos_jaap[cam] = i;
        cam = (jan_bet >> (21 - 3*i)) & 7;
        pos_jan[cam] = i;
        cam = (thijs_bet >> (21 - 3*i)) & 7;
        pos_thijs[cam] = i;
      end
    end
    // Count qualifying pairs
    logic [4:0] cnt;
    cnt = 5'd0;
    for (int c = 0; c < 8; c++) begin
      for (int d = c+1; d < 8; d++) begin
        if (c < n_int && d < n_int) begin
          if (pos_jaap[c] < pos_jaap[d] &&
              pos_jan[c] < pos_jan[d] &&
              pos_thijs[c] < pos_thijs[d]) begin
            cnt = cnt + 1;
          end
        end
      end
    end
    // Assign result
    count = cnt;
  end
endmodule