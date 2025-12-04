module hanabi_hints(
  input  [2:0]  num_cards,  // 1-8 cards
  input  [47:0] cards,      // 8 cards max (6 bits per card: [5:3]=color, [2:0]=value)
  output [3:0]  min_hints   // Minimum hint count (0-10)
);

  // Pre-decode card colors and values for up to 8 cards
  wire [2:0] color [7:0];
  wire [2:0] value [7:0];

  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : DECODE
      assign color[gi] = cards[gi*6 +: 3];
      assign value[gi] = cards[gi*6 + 3 +: 3];
    end
  endgenerate

  // Popcount of 10-bit value
  function automatic [3:0] popcount10(input [9:0] x);
    integer k;
    reg [3:0] c;
    begin
      c = 4'd0;
      for (k = 0; k < 10; k = k + 1) begin
        c = c + x[k];
      end
      popcount10 = c;
    end
  endfunction

  // Check if a given 10-bit hint mask is valid
  function automatic valid_mask(input [9:0] mask);
    // mask[9:5] : color hints for {R,G,B,Y,W}
    // mask[4:0] : value hints for {1,2,3,4,5}
    integer i, j;
    reg distinguishable;
    reg [2:0] ci, cj, vi, vj;
    reg [4:0] color_bit, value_bit;
    reg has_color_hint_i, has_value_hint_i, has_color_hint_j, has_value_hint_j;
    reg cond1, cond2, cond3;
    begin
      // Precompute nothing globally; work per pair
      if (num_cards <= 1) begin
        valid_mask = 1'b1; // Trivially valid
      end else begin
        valid_mask = 1'b1;
        // Iterate over all unordered pairs (i < j)
        for (i = 0; i < 8; i = i + 1) begin
          if (!valid_mask) disable for_i_break; // early break label
          if (i >= num_cards)
            disable for_i_break;
          for (j = i + 1; j < 8; j = j + 1) begin
            if (j >= num_cards)
              disable for_j_break;

            ci = color[i];
            cj = color[j];
            vi = value[i];
            vj = value[j];

            // Map color code to bit index 9:5
            // Only valid for 000-100; others unused but mapped safely
            color_bit = 5'b00000;
            case (ci)
              3'b000: color_bit[0] = 1'b1; // R -> bit5
              3'b001: color_bit[1] = 1'b1; // G -> bit6
              3'b010: color_bit[2] = 1'b1; // B -> bit7
              3'b011: color_bit[3] = 1'b1; // Y -> bit8
              3'b100: color_bit[4] = 1'b1; // W -> bit9
              default: color_bit = 5'b00000;
            endcase

            has_color_hint_i = |( (mask[9:5]) & color_bit );

            color_bit = 5'b00000;
            case (cj)
              3'b000: color_bit[0] = 1'b1;
              3'b001: color_bit[1] = 1'b1;
              3'b010: color_bit[2] = 1'b1;
              3'b011: color_bit[3] = 1'b1;
              3'b100: color_bit[4] = 1'b1;
              default: color_bit = 5'b00000;
            endcase

            has_color_hint_j = |( (mask[9:5]) & color_bit );

            // Map value code to bit index 4:0
            value_bit = 5'b00000;
            case (vi)
              3'b001: value_bit[0] = 1'b1; // 1 -> bit0
              3'b010: value_bit[1] = 1'b1; // 2 -> bit1
              3'b011: value_bit[2] = 1'b1; // 3 -> bit2
              3'b100: value_bit[3] = 1'b1; // 4 -> bit3
              3'b101: value_bit[4] = 1'b1; // 5 -> bit4
              default: value_bit = 5'b00000;
            endcase

            has_value_hint_i = |( (mask[4:0]) & value_bit );

            value_bit = 5'b00000;
            case (vj)
              3'b001: value_bit[0] = 1'b1;
              3'b010: value_bit[1] = 1'b1;
              3'b011: value_bit[2] = 1'b1;
              3'b100: value_bit[3] = 1'b1;
              3'b101: value_bit[4] = 1'b1;
              default: value_bit = 5'b00000;
            endcase

            has_value_hint_j = |( (mask[4:0]) & value_bit );

            // Condition 1: Different colors AND color hint exists for i or j
            cond1 = (ci != cj) && (has_color_hint_i || has_color_hint_j);

            // Condition 2: Different values AND value hint exists for i or j
            cond2 = (vi != vj) && (has_value_hint_i || has_value_hint_j);

            // Condition 3: Either card has at least one revealed attribute
            cond3 = (has_color_hint_i || has_value_hint_i ||
                     has_color_hint_j || has_value_hint_j);

            distinguishable = cond1 || cond2 || cond3;

            if (!distinguishable) begin
              valid_mask = 1'b0;
              disable for_j_break;
            end
          end
          for_j_break: ;
        end
        for_i_break: ;
      end
    end
  endfunction

  // Find minimal popcount of all valid masks (0..1023)
  reg [3:0] best;
  integer m;

  always @* begin
    best = 4'd10; // max hints is 10
    for (m = 0; m < 1024; m = m + 1) begin
      if (valid_mask(m[9:0])) begin
        if (popcount10(m[9:0]) < best) begin
          best = popcount10(m[9:0]);
        end
      end
    end
  end

  assign min_hints = best;

endmodule