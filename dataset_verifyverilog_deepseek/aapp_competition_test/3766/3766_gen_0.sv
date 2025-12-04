module hanabi_hints(
  input [2:0] num_cards,
  input [47:0] cards,
  output [3:0] min_hints
);

wire [2:0] color [0:7];
wire [2:0] value [0:7];

// Unpack cards
assign color[0] = cards[2:0];
assign value[0] = cards[5:3];
assign color[1] = cards[8:6];
assign value[1] = cards[11:9];
assign color[2] = cards[14:12];
assign value[2] = cards[17:15];
assign color[3] = cards[20:18];
assign value[3] = cards[23:21];
assign color[4] = cards[26:24];
assign value[4] = cards[29:27];
assign color[5] = cards[32:30];
assign value[5] = cards[35:33];
assign color[6] = cards[38:36];
assign value[6] = cards[41:39];
assign color[7] = cards[44:42];
assign value[7] = cards[47:45];

// Distinguish function
function automatic distinguishable(input [9:0] m, input integer i, j);
  reg [2:0] c_i = color[i];
  reg [2:0] c_j = color[j];
  reg [2:0] v_i = value[i];
  reg [2:0] v_j = value[j];
  
  // Color info
  wire color_hint_i = (c_i < 5) ? m[5 + c_i] : 1'b0;
  wire color_hint_j = (c_j < 5) ? m[5 + c_j] : 1'b0;
  reg color_diff = (c_i != c_j);
  reg cond1 = color_diff && (color_hint_i || color_hint_j);
  
  // Value info
  wire [3:0] v_num_i = (v_i == 3'b001) ? 1 : (v_i == 3'b010) ? 2 : (v_i == 3'b011) ? 3 : 
                        (v_i == 3'b100) ? 4 : (v_i == 3'b101) ? 5 : 0;
  wire [3:0] v_num_j = (v_j == 3'b001) ? 1 : (v_j == 3'b010) ? 2 : (v_j == 3'b011) ? 3 : 
                        (v_j == 3'b100) ? 4 : (v_j == 3'b101) ? 5 : 0;
  wire value_hint_i = (v_num_i >= 1 && v_num_i <=5) ? m[5 - v_num_i] : 1'b0;
  wire value_hint_j = (v_num_j >= 1 && v_num_j <=5) ? m[5 - v_num_j] : 1'b0;
  reg value_diff = (v_i != v_j);
  reg cond2 = value_diff && (value_hint_i || value_hint_j);
  
  // Any revealed attribute
  reg cond3 = (color_hint_i || value_hint_i || color_hint_j || value_hint_j);
  
  distinguishable = cond1 || cond2 || cond3;
endfunction

// Mask valid check
function automatic mask_valid(input [9:0] m);
  reg valid = 1'b1;
  for (int i=0; i<8; i++) begin
    for (int j=i+1; j<8; j++) begin
      if ((i < num_cards) && (j < num_cards)) begin
        if (!distinguishable(m, i, j)) begin
          valid = 1'b0;
        end
      end
    end
  end
  mask_valid = valid;
endfunction

// Popcount function
function automatic [3:0] popcount(input [9:0] v);
  popcount = $countones(v);
endfunction

// Compute min_hints
reg [3:0] min_temp;

always_comb begin
  min_temp = 4'b1010; // Initialize to 10 (max)
  for (int mask=0; mask<1024; mask++) begin
    if (mask_valid(mask)) begin
      reg [3:0] cnt = popcount(mask);
      if (cnt < min_temp) min_temp = cnt;
    end
  end
end

assign min_hints = min_temp;

endmodule