module answer_sequence_counter(input [2:0] n, input [3:0] m, input [111:0] hints_packed, output reg [31:0] valid_count);
  localparam MODULO = 32'h3B9ACA07;
  
  wire [255:0] seq_valid_flags;
  
  genvar s, j;
  generate
    for (s = 0; s < 256; s = s + 1) begin : seq_loop
      wire s_enabled = (s < (1 << n));
      wire [15:0] hint_valid;
      
      for (j = 0; j < 16; j = j + 1) begin : hint_loop
        wire active = (j < m);
        wire [6:0] hint = hints_packed[j*7 +: 7];
        wire [2:0] l = hint[6:4];
        wire [2:0] r = hint[3:1];
        wire type_h = hint[0];
        
        wire [2:0] l_eff = (l < n) ? l : (n - 1);
        wire [2:0] r_eff = (r < n) ? r : (n - 1);
        wire empty_range = (l_eff > r_eff);
        
        wire valid;
        
        if (empty_range) assign valid = type_h;
        else begin
          wire [7:0] seq_s = s;
          wire ref_bit = seq_s[l_eff];
          wire same_bit = 
              ((l_eff <= 0 && 0 <= r_eff) ? (seq_s[0] == ref_bit) : 1'b1) &
              ((l_eff <= 1 && 1 <= r_eff) ? (seq_s[1] == ref_bit) : 1'b1) &
              ((l_eff <= 2 && 2 <= r_eff) ? (seq_s[2] == ref_bit) : 1'b1) &
              ((l_eff <= 3 && 3 <= r_eff) ? (seq_s[3] == ref_bit) : 1'b1) &
              ((l_eff <= 4 && 4 <= r_eff) ? (seq_s[4] == ref_bit) : 1'b1) &
              ((l_eff <= 5 && 5 <= r_eff) ? (seq_s[5] == ref_bit) : 1'b1) &
              ((l_eff <= 6 && 6 <= r_eff) ? (seq_s[6] == ref_bit) : 1'b1) &
              ((l_eff <= 7 && 7 <= r_eff) ? (seq_s[7] == ref_bit) : 1'b1);
          
          assign valid = type_h ? same_bit : !same_bit;
        end
        
        assign hint_valid[j] = active ? valid : 1'b1;
      end
      
      assign seq_valid_flags[s] = s_enabled & (&hint_valid);
    end
  endgenerate
  
  integer idx;
  reg [31:0] count_reg;
  always_comb begin
    count_reg = 0;
    for (idx = 0; idx < 256; idx = idx + 1)
      if (seq_valid_flags[idx]) count_reg = count_reg + 1;
  end
  
  assign valid_count = count_reg % MODULO;
endmodule