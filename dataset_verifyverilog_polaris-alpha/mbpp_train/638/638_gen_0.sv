module wind_chill_calculator(
  input  [7:0] wind_velocity,
  input  [7:0] temperature,
  output reg [7:0] wind_chill
);

  // Internal signals
  reg  [31:0] lut_v;              // Q16.16 for v^0.16
  wire signed [31:0] t_q16;       // Q16.16 signed temperature
  wire [31:0] v_q16;              // Q16.16 unsigned wind velocity (not directly used in formula)

  // Constants in Q16.16
  localparam signed [31:0] C_13_12   = 32'sd859832;   // 13.12   * 65536
  localparam signed [31:0] C_0_6215  = 32'sd40806;    // 0.6215  * 65536
  localparam signed [31:0] C_M11_37  = -32'sd744904;  // -11.37  * 65536
  localparam signed [31:0] C_0_3965  = 32'sd25983;    // 0.3965  * 65536

  // Convert inputs to Q16.16
  assign t_q16 = $signed(temperature) <<< 16;
  assign v_q16 = {wind_velocity,16'd0};

  // LUT for v^0.16 in Q16.16 for v=0..255 (precomputed)
  // values = round((v**0.16)*65536)
  always @* begin
    case (wind_velocity)
      8'd0:   lut_v = 32'd0;
      8'd1:   lut_v = 32'd65536;
      8'd2:   lut_v = 32'd76672;
      8'd3:   lut_v = 32'd83280;
      8'd4:   lut_v = 32'd88207;
      8'd5:   lut_v = 32'd92177;
      8'd6:   lut_v = 32'd95546;
      8'd7:   lut_v = 32'd98469;
      8'd8:   lut_v = 32'd101182;
      8'd9:   lut_v = 32'd103733;
      8'd10:  lut_v = 32'd106149;
      8'd11:  lut_v = 32'd108452;
      8'd12:  lut_v = 32'd110658;
      8'd13:  lut_v = 32'd112781;
      8'd14:  lut_v = 32'd114831;
      8'd15:  lut_v = 32'd116819;
      8'd16:  lut_v = 32'd118752;
      8'd17:  lut_v = 32'd120636;
      8'd18:  lut_v = 32'd122476;
      8'd19:  lut_v = 32'd124276;
      8'd20:  lut_v = 32'd126040;
      8'd21:  lut_v = 32'd127772;
      8'd22:  lut_v = 32'd129473;
      8'd23:  lut_v = 32'd131147;
      8'd24:  lut_v = 32'd132795;
      8'd25:  lut_v = 32'd134420;
      8'd26:  lut_v = 32'd136022;
      8'd27:  lut_v = 32'd137604;
      8'd28:  lut_v = 32'd139166;
      8'd29:  lut_v = 32'd140710;
      8'd30:  lut_v = 32'd142237;
      8'd31:  lut_v = 32'd143748;
      8'd32:  lut_v = 32'd145243;
      8'd33:  lut_v = 32'd146724;
      8'd34:  lut_v = 32'd148190;
      8'd35:  lut_v = 32'd149643;
      8'd36:  lut_v = 32'd151083;
      8'd37:  lut_v = 32'd152511;
      8'd38:  lut_v = 32'd153927;
      8'd39:  lut_v = 32'd155332;
      8'd40:  lut_v = 32'd156726;
      8'd41:  lut_v = 32'd158110;
      8'd42:  lut_v = 32'd159484;
      8'd43:  lut_v = 32'd160849;
      8'd44:  lut_v = 32'd162204;
      8'd45:  lut_v = 32'd163551;
      8'd46:  lut_v = 32'd164889;
      8'd47:  lut_v = 32'd166220;
      8'd48:  lut_v = 32'd167542;
      8'd49:  lut_v = 32'd168857;
      8'd50:  lut_v = 32'd170166;
      8'd51:  lut_v = 32'd171467;
      8'd52:  lut_v = 32'd172762;
      8'd53:  lut_v = 32'd174051;
      8'd54:  lut_v = 32'd175334;
      8'd55:  lut_v = 32'd176611;
      8'd56:  lut_v = 32'd177883;
      8'd57:  lut_v = 32'd179149;
      8'd58:  lut_v = 32'd180411;
      8'd59:  lut_v = 32'd181667;
      8'd60:  lut_v = 32'd182919;
      8'd61:  lut_v = 32'd184166;
      8'd62:  lut_v = 32'd185409;
      8'd63:  lut_v = 32'd186648;
      8'd64:  lut_v = 32'd187882;
      8'd65:  lut_v = 32'd189113;
      8'd66:  lut_v = 32'd190340;
      8'd67:  lut_v = 32'd191563;
      8'd68:  lut_v = 32'd192783;
      8'd69:  lut_v = 32'd193999;
      8'd70:  lut_v = 32'd195212;
      8'd71:  lut_v = 32'd196422;
      8'd72:  lut_v = 32'd197629;
      8'd73:  lut_v = 32'd198833;
      8'd74:  lut_v = 32'd200034;
      8'd75:  lut_v = 32'd201232;
      8'd76:  lut_v = 32'd202427;
      8'd77:  lut_v = 32'd203620;
      8'd78:  lut_v = 32'd204810;
      8'd79:  lut_v = 32'd205998;
      8'd80:  lut_v = 32'd207183;
      8'd81:  lut_v = 32'd208365;
      8'd82:  lut_v = 32'd209546;
      8'd83:  lut_v = 32'd210724;
      8'd84:  lut_v = 32'd211899;
      8'd85:  lut_v = 32'd213073;
      8'd86:  lut_v = 32'd214244;
      8'd87:  lut_v = 32'd215413;
      8'd88:  lut_v = 32'd216580;
      8'd89:  lut_v = 32'd217745;
      8'd90:  lut_v = 32'd218908;
      8'd91:  lut_v = 32'd220069;
      8'd92:  lut_v = 32'd221228;
      8'd93:  lut_v = 32'd222385;
      8'd94:  lut_v = 32'd223540;
      8'd95:  lut_v = 32'd224693;
      8'd96:  lut_v = 32'd225845;
      8'd97:  lut_v = 32'd226994;
      8'd98:  lut_v = 32'd228142;
      8'd99:  lut_v = 32'd229288;
      8'd100: lut_v = 32'd230432;
      8'd101: lut_v = 32'd231574;
      8'd102: lut_v = 32'd232715;
      8'd103: lut_v = 32'd233854;
      8'd104: lut_v = 32'd234991;
      8'd105: lut_v = 32'd236127;
      8'd106: lut_v = 32'd237261;
      8'd107: lut_v = 32'd238394;
      8'd108: lut_v = 32'd239525;
      8'd109: lut_v = 32'd240654;
      8'd110: lut_v = 32'd241782;
      8'd111: lut_v = 32'd242909;
      8'd112: lut_v = 32'd244034;
      8'd113: lut_v = 32'd245158;
      8'd114: lut_v = 32'd246280;
      8'd115: lut_v = 32'd247401;
      8'd116: lut_v = 32'd248520;
      8'd117: lut_v = 32'd249639;
      8'd118: lut_v = 32'd250756;
      8'd119: lut_v = 32'd251871;
      8'd120: lut_v = 32'd252986;
      8'd121: lut_v = 32'd254099;
      8'd122: lut_v = 32'd255211;
      8'd123: lut_v = 32'd256322;
      8'd124: lut_v = 32'd257431;
      8'd125: lut_v = 32'd258539;
      8'd126: lut_v = 32'd259646;
      8'd127: lut_v = 32'd260752;
      8'd128: lut_v = 32'd261857;
      8'd129: lut_v = 32'd262960;
      8'd130: lut_v = 32'd264063;
      8'd131: lut_v = 32'd265164;
      8'd132: lut_v = 32'd266264;
      8'd133: lut_v = 32'd267363;
      8'd134: lut_v = 32'd268461;
      8'd135: lut_v = 32'd269558;
      8'd136: lut_v = 32'd270654;
      8'd137: lut_v = 32'd271749;
      8'd138: lut_v = 32'd272843;
      8'd139: lut_v = 32'd273936;
      8'd140: lut_v = 32'd275028;
      8'd141: lut_v = 32'd276118;
      8'd142: lut_v = 32'd277208;
      8'd143: lut_v = 32'd278297;
      8'd144: lut_v = 32'd279385;
      8'd145: lut_v = 32'd280472;
      8'd146: lut_v = 32'd281558;
      8'd147: lut_v = 32'd282643;
      8'd148: lut_v = 32'd283727;
      8'd149: lut_v = 32'd284810;
      8'd150: lut_v = 32'd285892;
      8'd151: lut_v = 32'd286974;
      8'd152: lut_v = 32'd288054;
      8'd153: lut_v = 32'd289134;
      8'd154: lut_v = 32'd290212;
      8'd155: lut_v = 32'd291290;
      8'd156: lut_v = 32'd292367;
      8'd157: lut_v = 32'd293443;
      8'd158: lut_v = 32'd294518;
      8'd159: lut_v = 32'd295592;
      8'd160: lut_v = 32'd296666;
      8'd161: lut_v = 32'd297738;
      8'd162: lut_v = 32'd298810;
      8'd163: lut_v = 32'd299881;
      8'd164: lut_v = 32'd300951;
      8'd165: lut_v = 32'd302020;
      8'd166: lut_v = 32'd303088;
      8'd167: lut_v = 32'd304155;
      8'd168: lut_v = 32'd305222;
      8'd169: lut_v = 32'd306287;
      8'd170: lut_v = 32'd307352;
      8'd171: lut_v = 32'd308416;
      8'd172: lut_v = 32'd309479;
      8'd173: lut_v = 32'd310541;
      8'd174: lut_v = 32'd311603;
      8'd175: lut_v = 32'd312663;
      8'd176: lut_v = 32'd313723;
      8'd177: lut_v = 32'd314782;
      8'd178: lut_v = 32'd315840;
      8'd179: lut_v = 32'd316898;
      8'd180: lut_v = 32'd317954;
      8'd181: lut_v = 32'd319010;
      8'd182: lut_v = 32'd320065;
      8'd183: lut_v = 32'd321119;
      8'd184: lut_v = 32'd322172;
      8'd185: lut_v = 32'd323225;
      8'd186: lut_v = 32'd324277;
      8'd187: lut_v = 32'd325328;
      8'd188: lut_v = 32'd326378;
      8'd189: lut_v = 32'd327428;
      8'd190: lut_v = 32'd328476;
      8'd191: lut_v = 32'd329524;
      8'd192: lut_v = 32'd330572;
      8'd193: lut_v = 32'd331618;
      8'd194: lut_v = 32'd332664;
      8'd195: lut_v = 32'd333709;
      8'd196: lut_v = 32'd334753;
      8'd197: lut_v = 32'd335797;
      8'd198: lut_v = 32'd336840;
      8'd199: lut_v = 32'd337882;
      8'd200: lut_v = 32'd338923;
      8'd201: lut_v = 32'd339964;
      8'd202: lut_v = 32'd341004;
      8'd203: lut_v = 32'd342043;
      8'd204: lut_v = 32'd343082;
      8'd205: lut_v = 32'd344119;
      8'd206: lut_v = 32'd345156;
      8'd207: lut_v = 32'd346193;
      8'd208: lut_v = 32'd347228;
      8'd209: lut_v = 32'd348263;
      8'd210: lut_v = 32'd349297;
      8'd211: lut_v = 32'd350331;
      8'd212: lut_v = 32'd351363;
      8'd213: lut_v = 32'd352396;
      8'd214: lut_v = 32'd353427;
      8'd215: lut_v = 32'd354458;
      8'd216: lut_v = 32'd355488;
      8'd217: lut_v = 32'd356517;
      8'd218: lut_v = 32'd357546;
      8'd219: lut_v = 32'd358574;
      8'd220: lut_v = 32'd359601;
      8'd221: lut_v = 32'd360627;
      8'd222: lut_v = 32'd361653;
      8'd223: lut_v = 32'd362678;
      8'd224: lut_v = 32'd363702;
      8'd225: lut_v = 32'd364726;
      8'd226: lut_v = 32'd365749;
      8'd227: lut_v = 32'd366771;
      8'd228: lut_v = 32'd367793;
      8'd229: lut_v = 32'd368814;
      8'd230: lut_v = 32'd369834;
      8'd231: lut_v = 32'd370854;
      8'd232: lut_v = 32'd371872;
      8'd233: lut_v = 32'd372891;
      8'd234: lut_v = 32'd373908;
      8'd235: lut_v = 32'd374925;
      8'd236: lut_v = 32'd375941;
      8'd237: lut_v = 32'd376956;
      8'd238: lut_v = 32'd377971;
      8'd239: lut_v = 32'd378985;
      8'd240: lut_v = 32'd379998;
      8'd241: lut_v = 32'd381011;
      8'd242: lut_v = 32'd382023;
      8'd243: lut_v = 32'd383034;
      8'd244: lut_v = 32'd384045;
      8'd245: lut_v = 32'd385055;
      8'd246: lut_v = 32'd386064;
      8'd247: lut_v = 32'd387072;
      8'd248: lut_v = 32'd388080;
      8'd249: lut_v = 32'd389087;
      8'd250: lut_v = 32'd390093;
      8'd251: lut_v = 32'd391099;
      8'd252: lut_v = 32'd392104;
      8'd253: lut_v = 32'd393109;
      8'd254: lut_v = 32'd394112;
      8'd255: lut_v = 32'd395116;
      default: lut_v = 32'd0;
    endcase
  end

  // Fixed-point computation (combinational)
  // Formula in Q16.16:
  // Wc = 13.12 + 0.6215*t - 11.37*LUT[v] + 0.3965*t*LUT[v]
  // Use 64-bit intermediates to avoid overflow.

  wire signed [63:0] term_const      = C_13_12;
  wire signed [63:0] term_t_lin      = (C_0_6215  * t_q16) >>> 16;              // Q16.16
  wire signed [63:0] term_v_pow      = (C_M11_37  * $signed(lut_v)) >>> 16;    // Q16.16
  wire signed [63:0] term_t_v_mul    = ( $signed(t_q16) * $signed(lut_v) ) >>> 16; // Q16.16
  wire signed [63:0] term_t_v        = (C_0_3965 * term_t_v_mul) >>> 16;       // Q16.16

  wire signed [63:0] wc_q16_full = term_const + term_t_lin + term_v_pow + term_t_v; // Q16.16

  // Round to nearest integer: add 0.5 (0x0000_8000) and truncate
  wire signed [63:0] wc_rounded = wc_q16_full + 64'sd32768; // 0.5 in Q16.16
  wire signed [31:0] wc_int     = wc_rounded[47:16];        // drop fraction

  // Clamp to 8-bit signed range (-128 to 127)
  always @* begin
    if (wc_int > 127)
      wind_chill = 8'sd127;
    else if (wc_int < -128)
      wind_chill = -8'sd128;
    else
      wind_chill = wc_int[7:0];
  end

endmodule