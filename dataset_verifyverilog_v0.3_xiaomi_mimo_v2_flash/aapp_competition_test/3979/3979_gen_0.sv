module bookland_ordering (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,               // number of words (1..8)
    input wire [3:0] m,               // alphabet size (1..8)
    // word data: for each word i (0..MAX_WORDS-1)
    input wire [3:0]  word_len  [0:7],   // length of word i
    input wire [31:0] word_data [0:7],   // packed letters: bits 3:0 = first, 7:4 = second, ... (each 4 bits)
    output reg yes,                    // 1 if possible
    output reg [3:0] k,                // number of letters to capitalize
    output reg [7:0] letters_out,      // bitmask of letters to capitalize (bit 0 = letter 1)
    output reg done                    // asserted when computation finishes
);

// Parameters for scaling
parameter MAX_WORDS = 8;
parameter MAX_LEN   = 8;
parameter MAX_M     = 8;

// Internal state
localparam [2:0] S_IDLE       = 3'b000;
localparam [2:0] S_CHECK_MASK = 3'b001;
localparam [2:0] S_CHECK_PAIR = 3'b010;
localparam [2:0] S_NEXT_MASK  = 3'b011;
localparam [2:0] S_FOUND      = 3'b100;
localparam [2:0] S_NO_RESULT  = 3'b101;
localparam [2:0] S_OUTPUT     = 3'b110;

reg [2:0] state;
reg [2:0] pair_idx;               // current adjacent pair index (0..n-2)
reg [MAX_M-1:0] current_mask;     // current subset of letters to capitalize

// Combinational signals for word selection
wire [3:0]  w1_len, w2_len;
wire [31:0] w1_data, w2_data;
wire valid;                       // comparator result

// Select the two words for the current pair
assign w1_len  = (pair_idx < n) ? word_len[pair_idx]   : 4'd0;
assign w1_data = (pair_idx < n) ? word_data[pair_idx]  : 32'd0;
assign w2_len  = (pair_idx + 1 < n) ? word_len[pair_idx+1]   : 4'd0;
assign w2_data = (pair_idx + 1 < n) ? word_data[pair_idx+1]  : 32'd0;

// Comparator: check whether word1 <= word2 under current_mask
always @(*) begin
    reg [3:0] a, b;
    reg cap_a, cap_b;
    reg diff_found;
    reg valid_int;
    integer j;

    diff_found = 0;
    valid_int  = 1;   // default: valid if no diff and len1 <= len2

    for (j = 0; j < MAX_LEN; j = j + 1) begin
        if (!diff_found && j < w1_len && j < w2_len) begin
            a = w1_data[j*4 +: 4];   // extract letter j from packed data
            b = w2_data[j*4 +: 4];
            if (a != b) begin
                diff_found = 1;
                cap_a = current_mask[a-1];   // a >= 1 always
                cap_b = current_mask[b-1];
                if (cap_a == cap_b) begin
                    valid_int = (a < b);
                end else if (cap_a < cap_b) begin  // a large, b small => a < b
                    valid_int = 1;
                end else begin                     // a small, b large => a > b
                    valid_int = 0;
                end
            end
        end
    end

    if (!diff_found) begin   // one word is prefix of the other
        valid_int = (w1_len <= w2_len);
    end

    valid = valid_int;
end

// Function to count number of 1's in a mask
function automatic [3:0] count_bits(input [MAX_M-1:0] mask);
    reg [3:0] cnt;
    integer i;
    cnt = 0;
    for (i = 0; i < MAX_M; i = i + 1) begin
        if (mask[i]) cnt = cnt + 1;
    end
    count_bits = cnt;
endfunction

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        yes <= 1'b0;
        k <= 4'd0;
        letters_out <= 8'd0;
        done <= 1'b0;
        current_mask <= 8'd0;
        pair_idx <= 3'd0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    if (n <= 4'd1) begin   // always ordered
                        yes <= 1'b1;
                        letters_out <= 8'd0;
                        k <= 4'd0;
                        state <= S_OUTPUT;
                    end else begin
                        current_mask <= 8'd0;
                        state <= S_CHECK_MASK;
                    end
                end
            end

            S_CHECK_MASK: begin
                pair_idx <= 3'd0;
                state <= S_CHECK_PAIR;
            end

            S_CHECK_PAIR: begin
                if (!valid) begin
                    state <= S_NEXT_MASK;
                end else begin
                    if (pair_idx == n - 2) begin   // all pairs checked
                        state <= S_FOUND;
                    end else begin
                        pair_idx <= pair_idx + 3'd1;   // move to next pair
                        // state remains S_CHECK_PAIR
                    end
                end
            end

            S_NEXT_MASK: begin
                if (current_mask == (1 << m) - 1) begin
                    state <= S_NO_RESULT;   // tried all subsets, none worked
                end else begin
                    current_mask <= current_mask + 1;
                    state <= S_CHECK_MASK;
                end
            end

            S_FOUND: begin
                yes <= 1'b1;
                letters_out <= current_mask;
                k <= count_bits(current_mask);
                state <= S_OUTPUT;
            end

            S_NO_RESULT: begin
                yes <= 1'b0;
                letters_out <= 8'd0;
                k <= 4'd0;
                state <= S_OUTPUT;
            end

            S_OUTPUT: begin
                done <= 1'b1;
                // stay here until reset
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule