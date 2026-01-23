module max_and_circle #(
    parameter N = 8,
    parameter MAX_K = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr [0:N-1],
    input wire [3:0] k,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SETUP = 4'd1;
    localparam [3:0] NEXT_START = 4'd2;
    localparam [3:0] NEXT_COMPOSITION = 4'd3;
    localparam [3:0] COMPUTE_OR = 4'd4;
    localparam [3:0] COMPUTE_AND = 4'd5;
    localparam [3:0] UPDATE_MAX = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;

    // Counters and registers
    reg [2:0] start_idx;           // Current start index (0 to N-1)
    reg [5:0] comp_idx;            // Current composition index
    reg [2:0] seg_idx;             // Current segment index
    reg [2:0] elem_idx;            // Current element index in segment
    reg [DATA_WIDTH-1:0] seg_or;   // OR of current segment
    reg [RESULT_WIDTH-1:0] seg_and; // AND of segment ORs
    reg [RESULT_WIDTH-1:0] max_result; // Maximum result found

    // Composition ROM (precomputed for K=1..4)
    // Format: For each K, store compositions as packed arrays
    // Each composition is a packed array of segment lengths
    // Total compositions: K=1:1, K=2:7, K=3:21, K=4:35
    // We'll use a case statement to select based on k

    // Composition counters for each K
    reg [5:0] comp_count;          // Total compositions for current K
    reg [5:0] comp_counter;        // Counter for current composition

    // Composition data storage
    reg [2:0] comp_data [0:34];     // Store up to 35 compositions (max for K=4)
    reg [2:0] current_comp [0:7];  // Current composition (8 segments max)

    // Generate compositions based on k
    always @(*) begin
        case (k)
            4'd1: begin  // K=1: [8]
                comp_count = 6'd1;
                comp_data[0] = 8'd8;
            end
            4'd2: begin  // K=2: 7 compositions
                comp_count = 6'd7;
                comp_data[0] = 8'd1; comp_data[1] = 8'd7;
                comp_data[2] = 8'd2; comp_data[3] = 8'd6;
                comp_data[4] = 8'd3; comp_data[5] = 8'd5;
                comp_data[6] = 8'd4; comp_data[7] = 8'd4;
                comp_data[8] = 8'd5; comp_data[9] = 8'd3;
                comp_data[10] = 8'd6; comp_data[11] = 8'd2;
                comp_data[12] = 8'd7; comp_data[13] = 8'd1;
            end
            4'd3: begin  // K=3: 21 compositions
                comp_count = 6'd21;
                // 1+1+6 and permutations
                comp_data[0] = 8'd1; comp_data[1] = 8'd1; comp_data[2] = 8'd6;
                comp_data[3] = 8'd1; comp_data[4] = 8'd6; comp_data[5] = 8'd1;
                comp_data[6] = 8'd6; comp_data[7] = 8'd1; comp_data[8] = 8'd1;
                // 1+2+5 and permutations
                comp_data[9] = 8'd1; comp_data[10] = 8'd2; comp_data[11] = 8'd5;
                comp_data[12] = 8'd1; comp_data[13] = 8'd5; comp_data[14] = 8'd2;
                comp_data[15] = 8'd2; comp_data[16] = 8'd1; comp_data[17] = 8'd5;
                comp_data[18] = 8'd2; comp_data[19] = 8'd5; comp_data[20] = 8'd1;
                comp_data[21] = 8'd5; comp_data[22] = 8'd1; comp_data[23] = 8'd2;
                comp_data[24] = 8'd5; comp_data[25] = 8'd2; comp_data[26] = 8'd1;
                // 1+3+4 and permutations
                comp_data[27] = 8'd1; comp_data[28] = 8'd3; comp_data[29] = 8'd4;
                comp_data[30] = 8'd1; comp_data[31] = 8'd4; comp_data[32] = 8'd3;
                comp_data[33] = 8'd3; comp_data[34] = 8'd1; comp_data[35] = 8'd4;
                comp_data[36] = 8'd3; comp_data[37] = 8'd4; comp_data[38] = 8'd1;
                comp_data[39] = 8'd4; comp_data[40] = 8'd1; comp_data[41] = 8'd3;
                comp_data[42] = 8'd4; comp_data[43] = 8'd3; comp_data[44] = 8'd1;
                // 2+2+4 and permutations
                comp_data[45] = 8'd2; comp_data[46] = 8'd2; comp_data[47] = 8'd4;
                comp_data[48] = 8'd2; comp_data[49] = 8'd4; comp_data[50] = 8'd2;
                comp_data[51] = 8'd4; comp_data[52] = 8'd2; comp_data[53] = 8'd2;
                // 2+3+3 and permutations
                comp_data[54] = 8'd2; comp_data[55] = 8'd3; comp_data[56] = 8'd3;
                comp_data[57] = 8'd3; comp_data[58] = 8'd2; comp_data[59] = 8'd3;
                comp_data[60] = 8'd3; comp_data[61] = 8'd3; comp_data[62] = 8'd2;
            end
            4'd4: begin  // K=4: 35 compositions
                comp_count = 6'd35;
                // 1+1+1+5 and permutations (4)
                comp_data[0] = 8'd1; comp_data[1] = 8'd1; comp_data[2] = 8'd1; comp_data[3] = 8'd5;
                comp_data[4] = 8'd1; comp_data[5] = 8'd1; comp_data[6] = 8'd5; comp_data[7] = 8'd1;
                comp_data[8] = 8'd1; comp_data[9] = 8'd5; comp_data[10] = 8'd1; comp_data[11] = 8'd1;
                comp_data[12] = 8'd5; comp_data[13] = 8'd1; comp_data[14] = 8'd1; comp_data[15] = 8'd1;
                // 1+1+2+4 and permutations (12)
                comp_data[16] = 8'd1; comp_data[17] = 8'd1; comp_data[18] = 8'd2; comp_data[19] = 8'd4;
                comp_data[20] = 8'd1; comp_data[21] = 8'd1; comp_data[22] = 8'd4; comp_data[23] = 8'd2;
                comp_data[24] = 8'd1; comp_data[25] = 8'd2; comp_data[26] = 8'd1; comp_data[27] = 8'd4;
                comp_data[28] = 8'd1; comp_data[29] = 8'd2; comp_data[30] = 8'd4; comp_data[31] = 8'd1;
                comp_data[32] = 8'd1; comp_data[33] = 8'd4; comp_data[34] = 8'd1; comp_data[35] = 8'd2;
                comp_data[36] = 8'd1; comp_data[37] = 8'd4; comp_data[38] = 8'd2; comp_data[39] = 8'd1;
                comp_data[40] = 8'd2; comp_data[41] = 8'd1; comp_data[42] = 8'd1; comp_data[43] = 8'd4;
                comp_data[44] = 8'd2; comp_data[45] = 8'd1; comp_data[46] = 8'd4; comp_data[47] = 8'd1;
                comp_data[48] = 8'd2; comp_data[49] = 8'd4; comp_data[50] = 8'd1; comp_data[51] = 8'd1;
                comp_data[52] = 8'd4; comp_data[53] = 8'd1; comp_data[54] = 8'd1; comp_data[55] = 8'd2;
                comp_data[56] = 8'd4; comp_data[57] = 8'd1; comp_data[58] = 8'd2; comp_data[59] = 8'd1;
                comp_data[60] = 8'd4; comp_data[61] = 8'd2; comp_data[62] = 8'd1; comp_data[63] = 8'd1;
                // 1+1+3+3 and permutations (4)
                comp_data[64] = 8'd1; comp_data[65] = 8'd1; comp_data[66] = 8'd3; comp_data[67] = 8'd3;
                comp_data[68] = 8'd1; comp_data[69] = 8'd3; comp_data[70] = 8'd1; comp_data[71] = 8'd3;
                comp_data[72] = 8'd1; comp_data[73] = 8'd3; comp_data[74] = 8'd3; comp_data[75] = 8'd1;
                comp_data[76] = 8'd3; comp_data[77] = 8'd1; comp_data[78] = 8'd1; comp_data[79] = 8'd3;
                comp_data[80] = 8'd3; comp_data[81] = 8'd1; comp_data[82] = 8'd3; comp_data[83] = 8'd1;
                comp_data[84] = 8'd3; comp_data[85] = 8'd3; comp_data[86] = 8'd1; comp_data[87] = 8'd1;
                // 1+2+2+3 and permutations (12)
                comp_data[88] = 8'd1; comp_data[89] = 8'd2; comp_data[90] = 8'd2; comp_data[91] = 8'd3;
                comp_data[92] = 8'd1; comp_data[93] = 8'd2; comp_data[94] = 8'd3; comp_data[95] = 8'd2;
                comp_data[96] = 8'd1; comp_data[97] = 8'd3; comp_data[98] = 8'd2; comp_data[99] = 8'd2;
                comp_data[100] = 8'd2; comp_data[101] = 8'd1; comp_data[102] = 8'd2; comp_data[103] = 8'd3;
                comp_data[104] = 8'd2; comp_data[105] = 8'd1; comp_data[106] = 8'd3; comp_data[107] = 8'd2;
                comp_data[108] = 8'd2; comp_data[109] = 8'd2; comp_data[110] = 8'd1; comp_data[111] = 8'd3;
                comp_data[112] = 8'd2; comp_data[113] = 8'd2; comp_data[114] = 8'd3; comp_data[115] = 8'd1;
                comp_data[116] = 8'd2; comp_data[117] = 8'd3; comp_data[118] = 8'd1; comp_data[119] = 8'd2;
                comp_data[120] = 8'd2; comp_data[121] = 8'd3; comp_data[122] = 8'd2; comp_data[123] = 8'd1;
                comp_data[124] = 8'd3; comp_data[125] = 8'd1; comp_data[126] = 8'd2; comp_data[127] = 8'd2;
                comp_data[128] = 8'd3; comp_data[129] = 8'd2; comp_data[130] = 8'd1; comp_data[131] = 8'd2;
                comp_data[132] = 8'd3; comp_data[133] = 8'd2; comp_data[134] = 8'd2; comp_data[135] = 8'd1;
                // 2+2+2+2 (1)
                comp_data[136] = 8'd2; comp_data[137] = 8'd2; comp_data[138] = 8'd2; comp_data[139] = 8'd2;
            end
            default: begin
                comp_count = 6'd0;
            end
        endcase
    end

    // Load current composition
    always @(*) begin
        if (k >= 4'd1 && k <= 4'd4) begin
            for (integer i = 0; i < k; i = i + 1) begin
                current_comp[i] = comp_data[comp_idx * 4 + i];
            end
        end else begin
            for (integer i = 0; i < 8; i = i + 1) begin
                current_comp[i] = 8'd0;
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            start_idx <= 3'd0;
            comp_idx <= 6'd0;
            seg_idx <= 3'd0;
            elem_idx <= 3'd0;
            seg_or <= 8'd0;
            seg_and <= 16'd0;
            max_result <= 16'd0;
            comp_counter <= 6'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end
            end
            SETUP: begin
                next_state = NEXT_START;
            end
            NEXT_START: begin
                if (start_idx == N - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = NEXT_COMPOSITION;
                end
            end
            NEXT_COMPOSITION: begin
                if (comp_idx == comp_count - 1) begin
                    next_state = NEXT_START;
                end else begin
                    next_state = COMPUTE_OR;
                end
            end
            COMPUTE_OR: begin
                if (elem_idx == current_comp[seg_idx] - 1) begin
                    if (seg_idx == k - 1) begin
                        next_state = COMPUTE_AND;
                    end else begin
                        next_state = COMPUTE_OR;
                    end
                end
            end
            COMPUTE_AND: begin
                next_state = UPDATE_MAX;
            end
            UPDATE_MAX: begin
                next_state = NEXT_COMPOSITION;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(*) begin
        case (state)
            SETUP: begin
                start_idx <= 3'd0;
                comp_idx <= 6'd0;
                seg_idx <= 3'd0;
                elem_idx <= 3'd0;
                seg_or <= 8'd0;
                seg_and <= 16'd0;
                max_result <= 16'd0;
                comp_counter <= 6'd0;
            end
            NEXT_START: begin
                start_idx <= start_idx + 3'd1;
                comp_idx <= 6'd0;
                seg_idx <= 3'd0;
                elem_idx <= 3'd0;
                seg_or <= 8'd0;
                seg_and <= 16'd0;
            end
            NEXT_COMPOSITION: begin
                comp_idx <= comp_idx + 6'd1;
                seg_idx <= 3'd0;
                elem_idx <= 3'd0;
                seg_or <= 8'd0;
                seg_and <= 16'd0;
            end
            COMPUTE_OR: begin
                if (elem_idx == 3'd0) begin
                    seg_or <= arr[(start_idx + elem_idx) % N];
                end else begin
                    seg_or <= seg_or | arr[(start_idx + elem_idx) % N];
                end
                if (elem_idx == current_comp[seg_idx] - 1) begin
                    if (seg_idx == 3'd0) begin
                        seg_and <= seg_or;
                    end else begin
                        seg_and <= seg_and & seg_or;
                    end
                    seg_idx <= seg_idx + 3'd1;
                    elem_idx <= 3'd0;
                    seg_or <= 8'd0;
                end else begin
                    elem_idx <= elem_idx + 3'd1;
                end
            end
            UPDATE_MAX: begin
                if (seg_and > max_result) begin
                    max_result <= seg_and;
                end
            end
            DONE_STATE: begin
                result <= max_result;
                done <= 1'b1;
            end
            default: begin
                result <= 16'd0;
                done <= 1'b0;
            end
        endcase
    end

endmodule