module courtyard_coverage (
    input clk,
    input rst_n,
    input start,
    input [31:0] angle_br,
    input [31:0] angle_tr,
    input [31:0] angle_tl,
    input [31:0] angle_bl,
    output reg [31:0] proportion,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CALCULATE_COVERAGE,
        COMPUTE_RESULT,
        DONE
    } state_t;

    state_t state;
    reg [5:0] point_counter;
    reg [31:0] covered_points;
    reg [31:0] x_q, y_q;
    reg [31:0] tan_br, tan_tr, tan_tl, tan_bl;

    // Pre-computed constants
    localparam [31:0] ONE_EIGHTH = 8192; // 1/8 in Q16.16
    localparam [31:0] ONE = 65536; // 1 in Q16.16
    localparam [31:0] ZERO = 0;

    // Tan LUT (simplified for synthesis)
    function automatic [31:0] tan_lut(input [31:0] angle_q);
        reg [31:0] angle_deg;
        angle_deg = angle_q / 65536;
        case (angle_deg)
            0: return 0;
            1: return 1745; // tan(1°)
            2: return 3492; // tan(2°)
            3: return 5241; // tan(3°)
            4: return 6993; // tan(4°)
            5: return 8749; // tan(5°)
            6: return 10510; // tan(6°)
            7: return 12277; // tan(7°)
            8: return 14050; // tan(8°)
            9: return 15830; // tan(9°)
            10: return 17617; // tan(10°)
            11: return 19412; // tan(11°)
            12: return 21215; // tan(12°)
            13: return 23027; // tan(13°)
            14: return 24849; // tan(14°)
            15: return 26681; // tan(15°)
            16: return 28525; // tan(16°)
            17: return 30381; // tan(17°)
            18: return 32250; // tan(18°)
            19: return 34133; // tan(19°)
            20: return 36030; // tan(20°)
            21: return 37943; // tan(21°)
            22: return 39872; // tan(22°)
            23: return 41818; // tan(23°)
            24: return 43782; // tan(24°)
            25: return 45765; // tan(25°)
            26: return 47768; // tan(26°)
            27: return 49792; // tan(27°)
            28: return 51838; // tan(28°)
            29: return 53908; // tan(29°)
            30: return 56003; // tan(30°)
            31: return 58124; // tan(31°)
            32: return 60273; // tan(32°)
            33: return 62451; // tan(33°)
            34: return 64659; // tan(34°)
            35: return 66900; // tan(35°)
            36: return 69175; // tan(36°)
            37: return 71486; // tan(37°)
            38: return 73835; // tan(38°)
            39: return 76224; // tan(39°)
            40: return 78655; // tan(40°)
            41: return 81130; // tan(41°)
            42: return 83652; // tan(42°)
            43: return 86223; // tan(43°)
            44: return 88846; // tan(44°)
            45: return 91524; // tan(45°)
            46: return 94258; // tan(46°)
            47: return 97052; // tan(47°)
            48: return 99908; // tan(48°)
            49: return 102830; // tan(49°)
            50: return 105821; // tan(50°)
            51: return 108885; // tan(51°)
            52: return 112025; // tan(52°)
            53: return 115244; // tan(53°)
            54: return 118547; // tan(54°)
            55: return 121938; // tan(55°)
            56: return 125422; // tan(56°)
            57: return 129004; // tan(57°)
            58: return 132690; // tan(58°)
            59: return 136486; // tan(59°)
            60: return 140399; // tan(60°)
            61: return 144436; // tan(61°)
            62: return 148605; // tan(62°)
            63: return 152915; // tan(63°)
            64: return 157376; // tan(64°)
            65: return 161999; // tan(65°)
            66: return 166797; // tan(66°)
            67: return 171784; // tan(67°)
            68: return 176977; // tan(68°)
            69: return 182395; // tan(69°)
            70: return 188060; // tan(70°)
            71: return 194000; // tan(71°)
            72: return 200247; // tan(72°)
            73: return 206839; // tan(73°)
            74: return 213824; // tan(74°)
            75: return 221264; // tan(75°)
            76: return 229238; // tan(76°)
            77: return 237847; // tan(77°)
            78: return 247221; // tan(78°)
            79: return 257522; // tan(79°)
            80: return 268950; // tan(80°)
            81: return 281756; // tan(81°)
            82: return 296304; // tan(82°)
            83: return 313244; // tan(83°)
            84: return 333686; // tan(84°)
            85: return 359774; // tan(85°)
            86: return 396710; // tan(86°)
            87: return 459560; // tan(87°)
            88: return 592720; // tan(88°)
            89: return 954240; // tan(89°)
            default: return 0;
        endcase
    endfunction

    // Coverage check for a point
    function automatic bit is_covered(input [31:0] x, input [31:0] y);
        reg [31:0] x_br, y_br;
        reg [31:0] x_tr, y_tr;
        reg [31:0] x_tl, y_tl;
        reg [31:0] x_bl, y_bl;
        reg covered;

        // Bottom-right sprinkler (1,0)
        x_br = x - ONE;
        y_br = y;
        covered = (y_br <= -$signed({1'b0, tan_br}) * $signed({1'b0, x_br})) && (x <= ONE) && (y >= ZERO);

        // Top-right sprinkler (1,1)
        x_tr = x - ONE;
        y_tr = y - ONE;
        covered = covered || ((y_tr <= -$signed({1'b0, tan_tr}) * $signed({1'b0, x_tr})) && (x <= ONE) && (y >= ZERO));

        // Top-left sprinkler (0,1)
        x_tl = x;
        y_tl = y - ONE;
        covered = covered || ((y_tl <= $signed({1'b0, tan_tl}) * $signed({1'b0, x_tl})) && (x >= ZERO) && (y <= ONE));

        // Bottom-left sprinkler (0,0)
        x_bl = x;
        y_bl = y;
        covered = covered || ((y_bl <= $signed({1'b0, tan_bl}) * $signed({1'b0, x_bl})) && (x >= ZERO) && (y >= ZERO));

        return covered;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            point_counter <= 0;
            covered_points <= 0;
            x_q <= 0;
            y_q <= 0;
            tan_br <= 0;
            tan_tr <= 0;
            tan_tl <= 0;
            tan_bl <= 0;
            proportion <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALCULATE_COVERAGE;
                        point_counter <= 0;
                        covered_points <= 0;
                        tan_br <= tan_lut(angle_br);
                        tan_tr <= tan_lut(angle_tr);
                        tan_tl <= tan_lut(angle_tl);
                        tan_bl <= tan_lut(angle_bl);
                    end
                end

                CALCULATE_COVERAGE: begin
                    if (point_counter < 64) begin
                        x_q = (point_counter % 8) * ONE_EIGHTH;
                        y_q = (point_counter / 8) * ONE_EIGHTH;
                        if (is_covered(x_q, y_q)) begin
                            covered_points <= covered_points + 1;
                        end
                        point_counter <= point_counter + 1;
                    end else begin
                        state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    proportion <= covered_points * 1024; // covered_points * 65536 / 64
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule