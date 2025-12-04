module hanabi_hints(
  input reg [2:0] num_cards,  // 1-8 cards (3-bit unsigned)
  input reg [47:0] cards,     // 8 cards max (6 bits per card: 3-bit color + 3-bit value)
  output reg [3:0] min_hints  // Minimum hint count (0-10)
);

  // Pre-extract the cards
  genvar g;
  generate
    for (g=0; g<8; g++) begin : extract
      wire [2:0] color = { cards[(g*6)+5], cards[(g*6)+4], cards[(g*6)+3] };
      wire [2:0] value = { cards[(g*6)+2], cards[(g*6)+1], cards[(g*6)] };
      wire [2:0] value_int = (value == 3'b001) ? 1 :
                            (value == 3'b010) ? 2 :
                            (value == 3'b011) ? 3 :
                            (value == 3'b100) ? 4 :
                            (value == 3'b101) ? 5 : 0;
    end
  endgenerate

  always @* begin
    min_hints = 4'd10;   // initialize to 10

    for (int mask=0; mask<1024; mask++) begin
      int pc = 0;
      for (int b=0; b<10; b++) begin
        pc = pc + mask[b];
      end

      if (pc >= min_hints) continue;

      int mask_valid = 1;
      for (int i=0; i<num_cards && mask_valid; i++) begin
        for (int j=i+1; j<num_cards; j++) begin
          int color_i = extract[i].color[0] + (extract[i].color[1]<<1) + (extract[i].color[2]<<2);
          int color_j = extract[j].color[0] + (extract[j].color[1]<<1) + (extract[j].color[2]<<2);

          int v_i = extract[i].value_int;
          int v_j = extract[j].value_int;

          int color_diff = (color_i != color_j);
          int value_diff = (v_i != v_j);

          int color_hint_i = (color_i >= 0 && color_i <= 4) ? mask[9 - color_i] : 1'b0;
          int color_hint_j = (color_j >= 0 && color_j <= 4) ? mask[9 - color_j] : 1'b0;
          int value_hint_i = (v_i >= 1 && v_i <= 5) ? mask[5 - v_i] : 1'b0;
          int value_hint_j = (v_j >= 1 && v_j <= 5) ? mask[5 - v_j] : 1'b0;

          int cond1 = color_diff && (color_hint_i || color_hint_j);
          int cond2 = value_diff && (value_hint_i || value_hint_j);
          int cond3 = ( (color_hint_i || value_hint_i) || (color_hint_j || value_hint_j) );

          if (!(cond1 || cond2 || cond3)) begin
            mask_valid = 0;
          end
        end
      end

      if (mask_valid) begin
        min_hints = pc;
      end
    end
  end

endmodule