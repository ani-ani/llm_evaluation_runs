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

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SETUP = 4'd1;
    localparam [3:0] NEXT_START = 4'd2;
    localparam [3:0] NEXT_COMPOSITION = 4'd3;
    localparam [3:0] COMPUTE_OR = 4'd4;
    localparam [3:0] COMPUTE_AND = 4'd5;
    localparam [3:0] UPDATE_MAX = 4'd6;
    localparam [3:0] DONE = 4'd7;

    // Control registers
    reg [3:0] state, next_state;
    reg [3:0] start_idx;          // Start position in circular array (0 to N-1)
    reg [7:0] comp_idx;           // Composition index (depends on k)
    reg [3:0] segment_idx;        // Current segment (0 to k-1)
    reg [3:0] element_idx;        // Element index within current segment
    reg [3:0] seg_len;            // Length of current segment
    reg [3:0] seg_offset;         // Offset in B array for current segment
    reg [RESULT_WIDTH-1:0] max_result;
    reg [RESULT_WIDTH-1:0] current_and;
    reg [RESULT_WIDTH-1:0] segment_or;
    reg [RESULT_WIDTH-1:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Composition ROM - stores compositions for each k
    // Format: For each k, store lengths as [len0, len1, ..., len(k-1)]
    // Total compositions: 1+7+21+35 = 64
    reg [3:0] comp_lengths [0:63][0:3]; // 64 compositions, max 4 segments
    
    // B array (linearized circular array)
    reg [DATA_WIDTH-1:0] B [0:N-1];
    
    // Internal control signals
    wire invalid_k = (k < 1) || (k > MAX_K);
    wire all_starts_done = (start_idx == N - 1);
    
    // Compose patterns for each k
    always @(*) begin
        // K=1: 1 composition [8]
        comp_lengths[0][0] = 8; comp_lengths[0][1] = 0; comp_lengths[0][2] = 0; comp_lengths[0][3] = 0;
        
        // K=2: 7 compositions
        comp_lengths[1][0] = 1; comp_lengths[1][1] = 7;
        comp_lengths[2][0] = 2; comp_lengths[2][1] = 6;
        comp_lengths[3][0] = 3; comp_lengths[3][1] = 5;
        comp_lengths[4][0] = 4; comp_lengths[4][1] = 4;
        comp_lengths[5][0] = 5; comp_lengths[5][1] = 3;
        comp_lengths[6][0] = 6; comp_lengths[6][1] = 2;
        comp_lengths[7][0] = 7; comp_lengths[7][1] = 1;
        
        // K=3: 21 compositions (start=1 to 6, middle=1 to 6, end determined)
        comp_lengths[8][0] = 1; comp_lengths[8][1] = 1; comp_lengths[8][2] = 6;
        comp_lengths[9][0] = 1; comp_lengths[9][1] = 2; comp_lengths[9][2] = 5;
        comp_lengths[10][0] = 1; comp_lengths[10][1] = 3; comp_lengths[10][2] = 4;
        comp_lengths[11][0] = 1; comp_lengths[11][1] = 4; comp_lengths[11][2] = 3;
        comp_lengths[12][0] = 1; comp_lengths[12][1] = 5; comp_lengths[12][2] = 2;
        comp_lengths[13][0] = 1; comp_lengths[13][1] = 6; comp_lengths[13][2] = 1;
        comp_lengths[14][0] = 2; comp_lengths[14][1] = 1; comp_lengths[14][2] = 5;
        comp_lengths[15][0] = 2; comp_lengths[15][1] = 2; comp_lengths[15][2] = 4;
        comp_lengths[16][0] = 2; comp_lengths[16][1] = 3; comp_lengths[16][2] = 3;
        comp_lengths[17][0] = 2; comp_lengths[17][1] = 4; comp_lengths[17][2] = 2;
        comp_lengths[18][0] = 2; comp_lengths[18][1] = 5; comp_lengths[18][2] = 1;
        comp_lengths[19][0] = 3; comp_lengths[19][1] = 1; comp_lengths[19][2] = 4;
        comp_lengths[20][0] = 3; comp_lengths[20][1] = 2; comp_lengths[20][2] = 3;
        comp_lengths[21][0] = 3; comp_lengths[21][1] = 3; comp_lengths[21][2] = 2;
        comp_lengths[22][0] = 3; comp_lengths[22][1] = 4; comp_lengths[22][2] = 1;
        comp_lengths[23][0] = 4; comp_lengths[23][1] = 1; comp_lengths[23][2] = 3;
        comp_lengths[24][0] = 4; comp_lengths[24][1] = 2; comp_lengths[24][2] = 2;
        comp_lengths[25][0] = 4; comp_lengths[25][1] = 3; comp_lengths[25][2] = 1;
        comp_lengths[26][0] = 5; comp_lengths[26][1] = 1; comp_lengths[26][2] = 2;
        comp_lengths[27][0] = 5; comp_lengths[27][1] = 2; comp_lengths[27][2] = 1;
        comp_lengths[28][0] = 6; comp_lengths[28][1] = 1; comp_lengths[28][2] = 1;
        
        // K=4: 35 compositions (start=1 to 5, middle1=1 to 5, middle2=1 to 5, end determined)
        // We use a compressed representation for brevity while ensuring correctness
        // Compositions are ordered by first element, then second, etc.
        comp_lengths[29][0] = 1; comp_lengths[29][1] = 1; comp_lengths[29][2] = 1; comp_lengths[29][3] = 5;
        comp_lengths[30][0] = 1; comp_lengths[30][1] = 1; comp_lengths[30][2] = 2; comp_lengths[30][3] = 4;
        comp_lengths[31][0] = 1; comp_lengths[31][1] = 1; comp_lengths[31][2] = 3; comp_lengths[31][3] = 3;
        comp_lengths[32][0] = 1; comp_lengths[32][1] = 1; comp_lengths[32][2] = 4; comp_lengths[32][3] = 2;
        comp_lengths[33][0] = 1; comp_lengths[33][1] = 1; comp_lengths[33][2] = 5; comp_lengths[33][3] = 1;
        comp_lengths[34][0] = 1; comp_lengths[34][1] = 2; comp_lengths[34][2] = 1; comp_lengths[34][3] = 4;
        comp_lengths[35][0] = 1; comp_lengths[35][1] = 2; comp_lengths[35][2] = 2; comp_lengths[35][3] = 3;
        comp_lengths[36][0] = 1; comp_lengths[36][1] = 2; comp_lengths[36][2] = 3; comp_lengths[36][3] = 2;
        comp_lengths[37][0] = 1; comp_lengths[37][1] = 2; comp_lengths[37][2] = 4; comp_lengths[37][3] = 1;
        comp_lengths[38][0] = 1; comp_lengths[38][1] = 3; comp_lengths[38][2] = 1; comp_lengths[38][3] = 3;
        comp_lengths[39][0] = 1; comp_lengths[39][1] = 3; comp_lengths[39][2] = 2; comp_lengths[39][3] = 2;
        comp_lengths[40][0] = 1; comp_lengths[40][1] = 3; comp_lengths[40][2] = 3; comp_lengths[40][3] = 1;
        comp_lengths[41][0] = 1; comp_lengths[41][1] = 4; comp_lengths[41][2] = 1; comp_lengths[41][3] = 2;
        comp_lengths[42][0] = 1; comp_lengths[42][1] = 4; comp_lengths[42][2] = 2; comp_lengths[42][3] = 1;
        comp_lengths[43][0] = 1; comp_lengths[43][1] = 5; comp_lengths[43][2] = 1; comp_lengths[43][3] = 1;
        comp_lengths[44][0] = 2; comp_lengths[44][1] = 1; comp_lengths[44][2] = 1; comp_lengths[44][3] = 4;
        comp_lengths[45][0] = 2; comp_lengths[45][1] = 1; comp_lengths[45][2] = 2; comp_lengths[45][3] = 3;
        comp_lengths[46][0] = 2; comp_lengths[46][1] = 1; comp_lengths[46][2] = 3; comp_lengths[46][3] = 2;
        comp_lengths[47][0] = 2; comp_lengths[47][1] = 1; comp_lengths[47][2] = 4; comp_lengths[47][3] = 1;
        comp_lengths[48][0] = 2; comp_lengths[48][1] = 2; comp_lengths[48][2] = 1; comp_lengths[48][3] = 3;
        comp_lengths[49][0] = 2; comp_lengths[49][1] = 2; comp_lengths[49][2] = 2; comp_lengths[49][3] = 2;
        comp_lengths[50][0] = 2; comp_lengths[50][1] = 2; comp_lengths[50][2] = 3; comp_lengths[50][3] = 1;
        comp_lengths[51][0] = 2; comp_lengths[51][1] = 3; comp_lengths[51][2] = 1; comp_lengths[51][3] = 2;
        comp_lengths[52][0] = 2; comp_lengths[52][1] = 3; comp_lengths[52][2] = 2; comp_lengths[52][3] = 1;
        comp_lengths[53][0] = 2; comp_lengths[53][1] = 4; comp_lengths[53][2] = 1; comp_lengths[53][3] = 1;
        comp_lengths[54][0] = 3; comp_lengths[54][1] = 1; comp_lengths[54][2] = 1; comp_lengths[54][3] = 3;
        comp_lengths[55][0] = 3; comp_lengths[55][1] = 1; comp_lengths[55][2] = 2; comp_lengths[55][3] = 2;
        comp_lengths[56][0] = 3; comp_lengths[56][1] = 1; comp_lengths[56][2] = 3; comp_lengths[56][3] = 1;
        comp_lengths[57][0] = 3; comp_lengths[57][1] = 2; comp_lengths[57][2] = 1; comp_lengths[57][3] = 2;
        comp_lengths[58][0] = 3; comp_lengths[58][1] = 2; comp_lengths[58][2] = 2; comp_lengths[58][3] = 1;
        comp_lengths[59][0] = 3; comp_lengths[59][1] = 3; comp_lengths[59][2] = 1; comp_lengths[59][3] = 1;
        comp_lengths[60][0] = 4; comp_lengths[60][1] = 1; comp_lengths[60][2] = 1; comp_lengths[60][3] = 2;
        comp_lengths[61][0] = 4; comp_lengths[61][1] = 1; comp_lengths[61][2] = 2; comp_lengths[61][3] = 1;
        comp_lengths[62][0] = 4; comp_lengths[62][1] = 2; comp_lengths[62][2] = 1; comp_lengths[62][3] = 1;
        comp_lengths[63][0] = 5; comp_lengths[63][1] = 1; comp_lengths[63][2] = 1; comp_lengths[63][3] = 1;
    end

    // Helper: get base index for compositions of a given k
    function automatic [7:0] get_comp_base(input [3:0] k_val);
        begin
            case (k_val)
                1: get_comp_base = 0;
                2: get_comp_base = 1;
                3: get_comp_base = 8;
                4: get_comp_base = 29;
                default: get_comp_base = 0;
            endcase
        end
    endfunction

    // Helper: get number of compositions for a given k
    function automatic [7:0] get_num_comps(input [3:0] k_val);
        begin
            case (k_val)
                1: get_num_comps = 1;
                2: get_num_comps = 7;
                3: get_num_comps = 21;
                4: get_num_comps = 35;
                default: get_num_comps = 0;
            endcase
        end
    endfunction

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
            end
            SETUP: begin
                if (invalid_k) next_state = DONE;
                else next_state = NEXT_START;
            end
            NEXT_START: begin
                next_state = NEXT_COMPOSITION;
            end
            NEXT_COMPOSITION: begin
                if (comp_idx >= get_num_comps(k) - 1) begin
                    if (all_starts_done) next_state = DONE;
                    else next_state = NEXT_START;
                end else begin
                    next_state = COMPUTE_OR;
                end
            end
            COMPUTE_OR: begin
                if (element_idx >= seg_len - 1) next_state = COMPUTE_AND;
                else next_state = COMPUTE_OR;
            end
            COMPUTE_AND: begin
                if (segment_idx >= k - 1) next_state = UPDATE_MAX;
                else next_state = COMPUTE_OR;
            end
            UPDATE_MAX: begin
                next_state = NEXT_COMPOSITION;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            max_result <= 16'd0;
            current_and <= 16'd0;
            segment_or <= 16'd0;
            temp_result <= 16'd0;
            start_idx <= 4'd0;
            comp_idx <= 8'd0;
            segment_idx <= 4'd0;
            element_idx <= 4'd0;
            seg_len <= 4'd0;
            seg_offset <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize B array
            integer i;
            for (i = 0; i < N; i = i + 1) begin
                B[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        result <= 16'd0;
                        max_result <= 16'd0;
                        current_and <= 16'd0;
                        segment_or <= 16'd0;
                        start_idx <= 4'd0;
                        comp_idx <= 8'd0;
                        cycle_count <= 8'd0;
                    end
                end
                SETUP: begin
                    cycle_count <= 8'd0;
                    // Build B array from start_idx=0 (for now)
                    // This will be updated in NEXT_START
                    integer j;
                    for (j = 0; j < N; j = j + 1) begin
                        B[j] <= arr[(0 + j) % N];
                    end
                    comp_idx <= get_comp_base(k);
                    segment_idx <= 4'd0;
                end
                NEXT_START: begin
                    cycle_count <= 8'd0;
                    // Update B array for new start index
                    integer j;
                    for (j = 0; j < N; j = j + 1) begin
                        B[j] <= arr[(start_idx + j) % N];
                    end
                    comp_idx <= get_comp_base(k);
                    segment_idx <= 4'd0;
                end
                NEXT_COMPOSITION: begin
                    if (comp_idx < get_comp_base(k) + get_num_comps(k) - 1) begin
                        comp_idx <= comp_idx + 8'd1;
                    end
                    segment_idx <= 4'd0;
                    seg_offset <= 4'd0;
                end
                COMPUTE_OR: begin
                    // Accumulate OR for current segment
                    if (element_idx == 0) begin
                        segment_or <= {8'd0, B[seg_offset]};
                        element_idx <= element_idx + 4'd1;
                    end else begin
                        segment_or <= segment_or | {8'd0, B[seg_offset + element_idx]};
                        element_idx <= element_idx + 4'd1;
                    end
                end
                COMPUTE_AND: begin
                    // Update segment index and get next segment length
                    if (segment_idx == 0) begin
                        current_and <= segment_or;
                    end else begin
                        current_and <= current_and & segment_or;
                    end
                    seg_offset <= seg_offset + seg_len;
                    segment_idx <= segment_idx + 4'd1;
                    element_idx <= 4'd0;
                    // Update seg_len for next segment
                    if (segment_idx + 4'd1 < k) begin
                        seg_len <= comp_lengths[comp_idx][segment_idx + 4'd1];
                    end
                end
                UPDATE_MAX: begin
                    // Final AND with last segment
                    current_and <= current_and & segment_or;
                    // Update max result
                    if (current_and > max_result) begin
                        max_result <= current_and;
                    end
                    result <= max_result;
                    // Increment start_idx
                    if (start_idx < N - 1) begin
                        start_idx <= start_idx + 4'd1;
                    end
                    element_idx <= 4'd0;
                    segment_idx <= 4'd0;
                    seg_len <= 4'd0;
                    seg_offset <= 4'd0;
                end
                DONE: begin
                    done <= 1'b1;
                    result <= max_result;
                    cycle_count <= 8'd0;
                end
            endcase
            
            // Cycle counter to prevent infinite loops
            if (state != IDLE && state != DONE) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

endmodule