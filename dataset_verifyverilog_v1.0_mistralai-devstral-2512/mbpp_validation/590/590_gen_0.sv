module polar_to_rect(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] polar_mag,
    input wire [15:0] polar_phi,
    output reg [15:0] rect_x,
    output reg [15:0] rect_y,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] QUAD_DET  = 4'd1;
    localparam [3:0] TABLE_LOOKUP = 4'd2;
    localparam [3:0] MULTIPLY  = 4'd3;
    localparam [3:0] FINISH    = 4'd4;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Internal signals
    reg [15:0] phi_reduced;
    reg [15:0] cos_val;
    reg [15:0] sin_val;
    reg [31:0] mult_temp_x;
    reg [31:0] mult_temp_y;
    reg [15:0] quadrant;
    reg [15:0] lookup_index;
    reg [15:0] lookup_count;

    // Lookup table for sin(0 to π/2) in Q16.16 format
    reg [15:0] sin_lut [0:255];

    // Initialize lookup table
    integer i;
    initial begin
        // Pre-calculated sin values for 0 to π/2 (0 to 32768 in Q16.16)
        // Values are scaled by 65536 (2^16)
        sin_lut[0]   = 16'd0;        // sin(0) = 0
        sin_lut[1]   = 16'd1029;     // sin(π/512)
        sin_lut[2]   = 16'd2058;     // sin(2π/512)
        sin_lut[3]   = 16'd3087;     // sin(3π/512)
        sin_lut[4]   = 16'd4116;     // sin(4π/512)
        sin_lut[5]   = 16'd5145;     // sin(5π/512)
        sin_lut[6]   = 16'd6174;     // sin(6π/512)
        sin_lut[7]   = 16'd7203;     // sin(7π/512)
        sin_lut[8]   = 16'd8232;     // sin(8π/512)
        sin_lut[9]   = 16'd9261;     // sin(9π/512)
        sin_lut[10]  = 16'd10290;    // sin(10π/512)
        sin_lut[11]  = 16'd11319;    // sin(11π/512)
        sin_lut[12]  = 16'd12348;    // sin(12π/512)
        sin_lut[13]  = 16'd13377;    // sin(13π/512)
        sin_lut[14]  = 16'd14406;    // sin(14π/512)
        sin_lut[15]  = 16'd15435;    // sin(15π/512)
        sin_lut[16]  = 16'd16464;    // sin(16π/512)
        sin_lut[17]  = 16'd17493;    // sin(17π/512)
        sin_lut[18]  = 16'd18522;    // sin(18π/512)
        sin_lut[19]  = 16'd19551;    // sin(19π/512)
        sin_lut[20]  = 16'd20580;    // sin(20π/512)
        sin_lut[21]  = 16'd21609;    // sin(21π/512)
        sin_lut[22]  = 16'd22638;    // sin(22π/512)
        sin_lut[23]  = 16'd23667;    // sin(23π/512)
        sin_lut[24]  = 16'd24696;    // sin(24π/512)
        sin_lut[25]  = 16'd25725;    // sin(25π/512)
        sin_lut[26]  = 16'd26754;    // sin(26π/512)
        sin_lut[27]  = 16'd27783;    // sin(27π/512)
        sin_lut[28]  = 16'd28812;    // sin(28π/512)
        sin_lut[29]  = 16'd29841;    // sin(29π/512)
        sin_lut[30]  = 16'd30870;    // sin(30π/512)
        sin_lut[31]  = 16'd31899;    // sin(31π/512)
        sin_lut[32]  = 16'd32928;    // sin(32π/512)
        sin_lut[33]  = 16'd33957;    // sin(33π/512)
        sin_lut[34]  = 16'd34986;    // sin(34π/512)
        sin_lut[35]  = 16'd36015;    // sin(35π/512)
        sin_lut[36]  = 16'd37044;    // sin(36π/512)
        sin_lut[37]  = 16'd38073;    // sin(37π/512)
        sin_lut[38]  = 16'd39102;    // sin(38π/512)
        sin_lut[39]  = 16'd40131;    // sin(39π/512)
        sin_lut[40]  = 16'd41160;    // sin(40π/512)
        sin_lut[41]  = 16'd42189;    // sin(41π/512)
        sin_lut[42]  = 16'd43218;    // sin(42π/512)
        sin_lut[43]  = 16'd44247;    // sin(43π/512)
        sin_lut[44]  = 16'd45276;    // sin(44π/512)
        sin_lut[45]  = 16'd46305;    // sin(45π/512)
        sin_lut[46]  = 16'd47334;    // sin(46π/512)
        sin_lut[47]  = 16'd48363;    // sin(47π/512)
        sin_lut[48]  = 16'd49392;    // sin(48π/512)
        sin_lut[49]  = 16'd50421;    // sin(49π/512)
        sin_lut[50]  = 16'd51450;    // sin(50π/512)
        sin_lut[51]  = 16'd52479;    // sin(51π/512)
        sin_lut[52]  = 16'd53508;    // sin(52π/512)
        sin_lut[53]  = 16'd54537;    // sin(53π/512)
        sin_lut[54]  = 16'd55566;    // sin(54π/512)
        sin_lut[55]  = 16'd56595;    // sin(55π/512)
        sin_lut[56]  = 16'd57624;    // sin(56π/512)
        sin_lut[57]  = 16'd58653;    // sin(57π/512)
        sin_lut[58]  = 16'd59682;    // sin(58π/512)
        sin_lut[59]  = 16'd60711;    // sin(59π/512)
        sin_lut[60]  = 16'd61740;    // sin(60π/512)
        sin_lut[61]  = 16'd62769;    // sin(61π/512)
        sin_lut[62]  = 16'd63798;    // sin(62π/512)
        sin_lut[63]  = 16'd64827;    // sin(63π/512)
        sin_lut[64]  = 16'd65856;    // sin(64π/512)
        sin_lut[65]  = 16'd66885;    // sin(65π/512)
        sin_lut[66]  = 16'd67914;    // sin(66π/512)
        sin_lut[67]  = 16'd68943;    // sin(67π/512)
        sin_lut[68]  = 16'd69972;    // sin(68π/512)
        sin_lut[69]  = 16'd71001;    // sin(69π/512)
        sin_lut[70]  = 16'd72030;    // sin(70π/512)
        sin_lut[71]  = 16'd73059;    // sin(71π/512)
        sin_lut[72]  = 16'd74088;    // sin(72π/512)
        sin_lut[73]  = 16'd75117;    // sin(73π/512)
        sin_lut[74]  = 16'd76146;    // sin(74π/512)
        sin_lut[75]  = 16'd77175;    // sin(75π/512)
        sin_lut[76]  = 16'd78204;    // sin(76π/512)
        sin_lut[77]  = 16'd79233;    // sin(77π/512)
        sin_lut[78]  = 16'd80262;    // sin(78π/512)
        sin_lut[79]  = 16'd81291;    // sin(79π/512)
        sin_lut[80]  = 16'd82320;    // sin(80π/512)
        sin_lut[81]  = 16'd83349;    // sin(81π/512)
        sin_lut[82]  = 16'd84378;    // sin(82π/512)
        sin_lut[83]  = 16'd85407;    // sin(83π/512)
        sin_lut[84]  = 16'd86436;    // sin(84π/512)
        sin_lut[85]  = 16'd87465;    // sin(85π/512)
        sin_lut[86]  = 16'd88494;    // sin(86π/512)
        sin_lut[87]  = 16'd89523;    // sin(87π/512)
        sin_lut[88]  = 16'd90552;    // sin(88π/512)
        sin_lut[89]  = 16'd91581;    // sin(89π/512)
        sin_lut[90]  = 16'd92610;    // sin(90π/512)
        sin_lut[91]  = 16'd93639;    // sin(91π/512)
        sin_lut[92]  = 16'd94668;    // sin(92π/512)
        sin_lut[93]  = 16'd95697;    // sin(93π/512)
        sin_lut[94]  = 16'd96726;    // sin(94π/512)
        sin_lut[95]  = 16'd97755;    // sin(95π/512)
        sin_lut[96]  = 16'd98784;    // sin(96π/512)
        sin_lut[97]  = 16'd99813;    // sin(97π/512)
        sin_lut[98]  = 16'd100842;   // sin(98π/512)
        sin_lut[99]  = 16'd101871;   // sin(99π/512)
        sin_lut[100] = 16'd102900;   // sin(100π/512)
        sin_lut[101] = 16'd103929;   // sin(101π/512)
        sin_lut[102] = 16'd104958;   // sin(102π/512)
        sin_lut[103] = 16'd105987;   // sin(103π/512)
        sin_lut[104] = 16'd107016;   // sin(104π/512)
        sin_lut[105] = 16'd108045;   // sin(105π/512)
        sin_lut[106] = 16'd109074;   // sin(106π/512)
        sin_lut[107] = 16'd110103;   // sin(107π/512)
        sin_lut[108] = 16'd111132;   // sin(108π/512)
        sin_lut[109] = 16'd112161;   // sin(109π/512)
        sin_lut[110] = 16'd113190;   // sin(110π/512)
        sin_lut[111] = 16'd114219;   // sin(111π/512)
        sin_lut[112] = 16'd115248;   // sin(112π/512)
        sin_lut[113] = 16'd116277;   // sin(113π/512)
        sin_lut[114] = 16'd117306;   // sin(114π/512)
        sin_lut[115] = 16'd118335;   // sin(115π/512)
        sin_lut[116] = 16'd119364;   // sin(116π/512)
        sin_lut[117] = 16'd120393;   // sin(117π/512)
        sin_lut[118] = 16'd121422;   // sin(118π/512)
        sin_lut[119] = 16'd122451;   // sin(119π/512)
        sin_lut[120] = 16'd123480;   // sin(120π/512)
        sin_lut[121] = 16'd124509;   // sin(121π/512)
        sin_lut[122] = 16'd125538;   // sin(122π/512)
        sin_lut[123] = 16'd126567;   // sin(123π/512)
        sin_lut[124] = 16'd127596;   // sin(124π/512)
        sin_lut[125] = 16'd128625;   // sin(125π/512)
        sin_lut[126] = 16'd129654;   // sin(126π/512)
        sin_lut[127] = 16'd130683;   // sin(127π/512)
        sin_lut[128] = 16'd131712;   // sin(128π/512)
        sin_lut[129] = 16'd132741;   // sin(129π/512)
        sin_lut[130] = 16'd133770;   // sin(130π/512)
        sin_lut[131] = 16'd134799;   // sin(131π/512)
        sin_lut[132] = 16'd135828;   // sin(132π/512)
        sin_lut[133] = 16'd136857;   // sin(133π/512)
        sin_lut[134] = 16'd137886;   // sin(134π/512)
        sin_lut[135] = 16'd138915;   // sin(135π/512)
        sin_lut[136] = 16'd139944;   // sin(136π/512)
        sin_lut[137] = 16'd140973;   // sin(137π/512)
        sin_lut[138] = 16'd142002;   // sin(138π/512)
        sin_lut[139] = 16'd143031;   // sin(139π/512)
        sin_lut[140] = 16'd144060;   // sin(140π/512)
        sin_lut[141] = 16'd145089;   // sin(141π/512)
        sin_lut[142] = 16'd146118;   // sin(142π/512)
        sin_lut[143] = 16'd147147;   // sin(143π/512)
        sin_lut[144] = 16'd148176;   // sin(144π/512)
        sin_lut[145] = 16'd149205;   // sin(145π/512)
        sin_lut[146] = 16'd150234;   // sin(146π/512)
        sin_lut[147] = 16'd151263;   // sin(147π/512)
        sin_lut[148] = 16'd152292;   // sin(148π/512)
        sin_lut[149] = 16'd153321;   // sin(149π/512)
        sin_lut[150] = 16'd154350;   // sin(150π/512)
        sin_lut[151] = 16'd155379;   // sin(151π/512)
        sin_lut[152] = 16'd156408;   // sin(152π/512)
        sin_lut[153] = 16'd157437;   // sin(153π/512)
        sin_lut[154] = 16'd158466;   // sin(154π/512)
        sin_lut[155] = 16'd159495;   // sin(155π/512)
        sin_lut[156] = 16'd160524;   // sin(156π/512)
        sin_lut[157] = 16'd161553;   // sin(157π/512)
        sin_lut[158] = 16'd162582;   // sin(158π/512)
        sin_lut[159] = 16'd163611;   // sin(159π/512)
        sin_lut[160] = 16'd164640;   // sin(160π/512)
        sin_lut[161] = 16'd165669;   // sin(161π/512)
        sin_lut[162] = 16'd166698;   // sin(162π/512)
        sin_lut[163] = 16'd167727;   // sin(163π/512)
        sin_lut[164] = 16'd168756;   // sin(164π/512)
        sin_lut[165] = 16'd169785;   // sin(165π/512)
        sin_lut[166] = 16'd170814;   // sin(166π/512)
        sin_lut[167] = 16'd171843;   // sin(167π/512)
        sin_lut[168] = 16'd172872;   // sin(168π/512)
        sin_lut[169] = 16'd173901;   // sin(169π/512)
        sin_lut[170] = 16'd174930;   // sin(170π/512)
        sin_lut[171] = 16'd175959;   // sin(171π/512)
        sin_lut[172] = 16'd176988;   // sin(172π/512)
        sin_lut[173] = 16'd178017;   // sin(173π/512)
        sin_lut[174] = 16'd179046;   // sin(174π/512)
        sin_lut[175] = 16'd180075;   // sin(175π/512)
        sin_lut[176] = 16'd181104;   // sin(176π/512)
        sin_lut[177] = 16'd182133;   // sin(177π/512)
        sin_lut[178] = 16'd183162;   // sin(178π/512)
        sin_lut[179] = 16'd184191;   // sin(179π/512)
        sin_lut[180] = 16'd185220;   // sin(180π/512)
        sin_lut[181] = 16'd186249;   // sin(181π/512)
        sin_lut[182] = 16'd187278;   // sin(182π/512)
        sin_lut[183] = 16'd188307;   // sin(183π/512)
        sin_lut[184] = 16'd189336;   // sin(184π/512)
        sin_lut[185] = 16'd190365;   // sin(185π/512)
        sin_lut[186] = 16'd191394;   // sin(186π/512)
        sin_lut[187] = 16'd192423;   // sin(187π/512)
        sin_lut[188] = 16'd193452;   // sin(188π/512)
        sin_lut[189] = 16'd194481;   // sin(189π/512)
        sin_lut[190] = 16'd195510;   // sin(190π/512)
        sin_lut[191] = 16'd196539;   // sin(191π/512)
        sin_lut[192] = 16'd197568;   // sin(192π/512)
        sin_lut[193] = 16'd198597;   // sin(193π/512)
        sin_lut[194] = 16'd199626;   // sin(194π/512)
        sin_lut[195] = 16'd200655;   // sin(195π/512)
        sin_lut[196] = 16'd201684;   // sin(196π/512)
        sin_lut[197] = 16'd202713;   // sin(197π/512)
        sin_lut[198] = 16'd203742;   // sin(198π/512)
        sin_lut[199] = 16'd204771;   // sin(199π/512)
        sin_lut[200] = 16'd205800;   // sin(200π/512)
        sin_lut[201] = 16'd206829;   // sin(201π/512)
        sin_lut[202] = 16'd207858;   // sin(202π/512)
        sin_lut[203] = 16'd208887;   // sin(203π/512)
        sin_lut[204] = 16'd209916;   // sin(204π/512)
        sin_lut[205] = 16'd210945;   // sin(205π/512)
        sin_lut[206] = 16'd211974;   // sin(206π/512)
        sin_lut[207] = 16'd213003;   // sin(207π/512)
        sin_lut[208] = 16'd214032;   // sin(208π/512)
        sin_lut[209] = 16'd215061;   // sin(209π/512)
        sin_lut[210] = 16'd216090;   // sin(210π/512)
        sin_lut[211] = 16'd217119;   // sin(211π/512)
        sin_lut[212] = 16'd218148;   // sin(212π/512)
        sin_lut[213] = 16'd219177;   // sin(213π/512)
        sin_lut[214] = 16'd220206;   // sin(214π/512)
        sin_lut[215] = 16'd221235;   // sin(215π/512)
        sin_lut[216] = 16'd222264;   // sin(216π/512)
        sin_lut[217] = 16'd223293;   // sin(217π/512)
        sin_lut[218] = 16'd224322;   // sin(218π/512)
        sin_lut[219] = 16'd225351;   // sin(219π/512)
        sin_lut[220] = 16'd226380;   // sin(220π/512)
        sin_lut[221] = 16'd227409;   // sin(221π/512)
        sin_lut[222] = 16'd228438;   // sin(222π/512)
        sin_lut[223] = 16'd229467;   // sin(223π/512)
        sin_lut[224] = 16'd230496;   // sin(224π/512)
        sin_lut[225] = 16'd231525;   // sin(225π/512)
        sin_lut[226] = 16'd232554;   // sin(226π/512)
        sin_lut[227] = 16'd233583;   // sin(227π/512)
        sin_lut[228] = 16'd234612;   // sin(228π/512)
        sin_lut[229] = 16'd235641;   // sin(229π/512)
        sin_lut[230] = 16'd236670;   // sin(230π/512)
        sin_lut[231] = 16'd237699;   // sin(231π/512)
        sin_lut[232] = 16'd238728;   // sin(232π/512)
        sin_lut[233] = 16'd239757;   // sin(233π/512)
        sin_lut[234] = 16'd240786;   // sin(234π/512)
        sin_lut[235] = 16'd241815;   // sin(235π/512)
        sin_lut[236] = 16'd242844;   // sin(236π/512)
        sin_lut[237] = 16'd243873;   // sin(237π/512)
        sin_lut[238] = 16'd244902;   // sin(238π/512)
        sin_lut[239] = 16'd245931;   // sin(239π/512)
        sin_lut[240] = 16'd246960;   // sin(240π/512)
        sin_lut[241] = 16'd247989;   // sin(241π/512)
        sin_lut[242] = 16'd249018;   // sin(242π/512)
        sin_lut[243] = 16'd250047;   // sin(243π/512)
        sin_lut[244] = 16'd251076;   // sin(244π/512)
        sin_lut[245] = 16'd252105;   // sin(245π/512)
        sin_lut[246] = 16'd253134;   // sin(246π/512)
        sin_lut[247] = 16'd254163;   // sin(247π/512)
        sin_lut[248] = 16'd255192;   // sin(248π/512)
        sin_lut[249] = 16'd256221;   // sin(249π/512)
        sin_lut[250] = 16'd257250;   // sin(250π/512)
        sin_lut[251] = 16'd258279;   // sin(251π/512)
        sin_lut[252] = 16'd259308;   // sin(252π/512)
        sin_lut[253] = 16'd260337;   // sin(253π/512)
        sin_lut[254] = 16'd261366;   // sin(254π/512)
        sin_lut[255] = 16'd262395;   // sin(255π/512)
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rect_x <= 16'd0;
            rect_y <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            phi_reduced <= 16'd0;
            cos_val <= 16'd0;
            sin_val <= 16'd0;
            mult_temp_x <= 32'd0;
            mult_temp_y <= 32'd0;
            quadrant <= 16'd0;
            lookup_index <= 16'd0;
            lookup_count <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= QUAD_DET;
                    end
                end

                QUAD_DET: begin
                    // Determine quadrant and reduce phi to 0-π/2 range
                    if (polar_phi < 16'd16384) begin  // Q1: 0 to π/2
                        quadrant <= 16'd0;
                        phi_reduced <= polar_phi;
                    end else if (polar_phi < 16'd32768) begin  // Q2: π/2 to π
                        quadrant <= 16'd1;
                        phi_reduced <= 16'd32768 - polar_phi;
                    end else if (polar_phi < 16'd49152) begin  // Q3: π to 3π/2
                        quadrant <= 16'd2;
                        phi_reduced <= polar_phi - 16'd32768;
                    end else begin  // Q4: 3π/2 to 2π
                        quadrant <= 16'd3;
                        phi_reduced <= 16'd65536 - polar_phi;
                    end

                    // Scale phi_reduced to 0-255 range for LUT
                    lookup_index <= phi_reduced[15:8];
                    state <= TABLE_LOOKUP;
                end

                TABLE_LOOKUP: begin
                    // Lookup sin and cos values
                    sin_val <= sin_lut[lookup_index];
                    cos_val <= sin_lut[255 - lookup_index];  // cos(θ) = sin(π/2 - θ)

                    lookup_count <= lookup_count + 16'd1;
                    if (lookup_count >= 16'd8) begin
                        state <= MULTIPLY;
                        lookup_count <= 16'd0;
                    end
                end

                MULTIPLY: begin
                    // Multiply r * cos_val and r * sin_val (32-bit intermediate)
                    mult_temp_x <= $signed(polar_mag) * $signed(cos_val);
                    mult_temp_y <= $signed(polar_mag) * $signed(sin_val);

                    // Apply quadrant signs
                    case (quadrant)
                        16'd0: begin  // Q1: x=+, y=+
                            rect_x <= mult_temp_x[31:16];
                            rect_y <= mult_temp_y[31:16];
                        end
                        16'd1: begin  // Q2: x=-, y=+
                            rect_x <= -mult_temp_x[31:16];
                            rect_y <= mult_temp_y[31:16];
                        end
                        16'd2: begin  // Q3: x=-, y=-
                            rect_x <= -mult_temp_x[31:16];
                            rect_y <= -mult_temp_y[31:16];
                        end
                        16'd3: begin  // Q4: x=+, y=-
                            rect_x <= mult_temp_x[31:16];
                            rect_y <= -mult_temp_y[31:16];
                        end
                        default: begin
                            rect_x <= 16'd0;
                            rect_y <= 16'd0;
                        end
                    endcase

                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd4) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule