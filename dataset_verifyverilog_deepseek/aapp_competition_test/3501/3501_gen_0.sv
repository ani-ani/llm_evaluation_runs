module camel_order_verifier(
  input [2:0] n,
  input [23:0] jaap_bet,
  input [23:0] jan_bet,
  input [23:0] thijs_bet,
  output reg [4:0] count
);

  wire [2:0] jaap_camels [0:7];
  wire [2:0] jan_camels [0:7];
  wire [2:0] thijs_camels [0:7];

  assign jaap_camels[0] = jaap_bet[23:21];
  assign jaap_camels[1] = jaap_bet[20:18];
  assign jaap_camels[2] = jaap_bet[17:15];
  assign jaap_camels[3] = jaap_bet[14:12];
  assign jaap_camels[4] = jaap_bet[11:9];
  assign jaap_camels[5] = jaap_bet[8:6];
  assign jaap_camels[6] = jaap_bet[5:3];
  assign jaap_camels[7] = jaap_bet[2:0];

  assign jan_camels[0] = jan_bet[23:21];
  assign jan_camels[1] = jan_bet[20:18];
  assign jan_camels[2] = jan_bet[17:15];
  assign jan_camels[3] = jan_bet[14:12];
  assign jan_camels[4] = jan_bet[11:9];
  assign jan_camels[5] = jan_bet[8:6];
  assign jan_camels[6] = jan_bet[5:3];
  assign jan_camels[7] = jan_bet[2:0];

  assign thijs_camels[0] = thijs_bet[23:21];
  assign thijs_camels[1] = thijs_bet[20:18];
  assign thijs_camels[2] = thijs_bet[17:15];
  assign thijs_camels[3] = thijs_bet[14:12];
  assign thijs_camels[4] = thijs_bet[11:9];
  assign thijs_camels[5] = thijs_bet[8:6];
  assign thijs_camels[6] = thijs_bet[5:3];
  assign thijs_camels[7] = thijs_bet[2:0];

  reg [2:0] jaap_pos [1:8];
  reg [2:0] jan_pos [1:8];
  reg [2:0] thijs_pos [1:8];

  integer i, c, d;

  always_comb begin
    for (i = 1; i <= 8; i = i + 1) begin
      jaap_pos[i] = 3'b111;
      jan_pos[i] = 3'b111;
      thijs_pos[i] = 3'b111;
    end

    for (i = 0; i < 8; i = i + 1) begin
      if (i < n) begin
        jaap_pos[jaap_camels[i]] = i;
        jan_pos[jan_camels[i]] = i;
        thijs_pos[thijs_camels[i]] = i;
      end
    end

    count = 0;
    for (c = 1; c <= 8; c = c + 1) begin
      for (d = c + 1; d <= 8; d = d + 1) begin
        if (c <= n && d <= n) begin
          if ((jaap_pos[c] < jaap_pos[d]) && 
              (jan_pos[c] < jan_pos[d]) && 
              (thijs_pos[c] < thijs_pos[d])) begin
            count = count + 1;
          end
        end
      end
    end
  end

endmodule