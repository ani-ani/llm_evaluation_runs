module autocorrect_min_keystrokes #(
    parameter NUM_DICT_WORDS = 8,
    parameter MAX_WORD_LEN = 16
)(
    // System signals
    input clk,
    input rst_n,
    input start,
    
    // Dictionary words (packed as 16x8-bit arrays)
    input [127:0] dict_words_packed [0:NUM_DICT_WORDS-1],
    input [4:0] dict_lens [0:NUM_DICT_WORDS-1],
    
    // Input word to type
    input [127:0] input_word_packed,
    input [4:0] input_len,
    
    // Output
    output reg [7:0] result,
    output reg done
);

// Unpack dictionary and input words into 2D arrays for easier access
wire [7:0] dict_words [0:NUM_DICT_WORDS-1][0:MAX_WORD_LEN-1];
wire [7:0] input_word [0:MAX_WORD_LEN-1];

integer i_idx, j_idx;
always @(*) begin
    for (i_idx = 0; i_idx < NUM_DICT_WORDS; i_idx = i_idx + 1) begin
        for (j_idx = 0; j_idx < MAX_WORD_LEN; j_idx = j_idx + 1) begin
            dict_words[i_idx][j_idx] = dict_words_packed[i_idx][j_idx*8 +: 8];
        end
    end
    for (j_idx = 0; j_idx < MAX_WORD_LEN; j_idx = j_idx + 1) begin
        input_word[j_idx] = input_word_packed[j_idx*8 +: 8];
    end
end

// State machine states
localparam [3:0] IDLE        = 4'd0;
localparam [3:0] INIT        = 4'd1;
localparam [3:0] SETUP_PREFIX = 4'd2;
localparam [3:0] SETUP_DICT  = 4'd3;
localparam [3:0] CHECK_PREFIX = 4'd4;
localparam [3:0] CALC_COMMON = 4'd5;
localparam [3:0] CALC_COST   = 4'd6;
localparam [3:0] UPDATE_MIN  = 4'd7;
localparam [3:0] NEXT_DICT   = 4'd8;
localparam [3:0] NEXT_PREFIX = 4'd9;
localparam [3:0] DONE_STATE  = 4'd10;

// Internal registers
reg [3:0] state;
reg [4:0] prefix_len;
reg [2:0] dict_idx;
reg [7:0] min_keystrokes;
reg [7:0] cost;
reg [4:0] common_len;
reg prefix_match;
reg [4:0] cmp_idx;

// Combinational logic: check prefix match
always @(*) begin
    prefix_match = 1;
    if (prefix_len > input_len || prefix_len > dict_lens[dict_idx]) begin
        prefix_match = 0;
    end else begin
        for (cmp_idx = 0; cmp_idx < prefix_len; cmp_idx = cmp_idx + 1) begin
            if (input_word[cmp_idx] != dict_words[dict_idx][cmp_idx]) begin
                prefix_match = 0;
            end
        end
    end
end

// Combinational logic: calculate common prefix length
always @(*) begin
    common_len = 0;
    for (cmp_idx = 0; cmp_idx < MAX_WORD_LEN; cmp_idx = cmp_idx + 1) begin
        if (cmp_idx < input_len && cmp_idx < dict_lens[dict_idx] && 
            input_word[cmp_idx] == dict_words[dict_idx][cmp_idx]) begin
            common_len = cmp_idx + 1;
        end
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        prefix_len <= 0;
        dict_idx <= 0;
        min_keystrokes <= 0;
        cost <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    state <= INIT;
                end
            end
            
            INIT: begin
                min_keystrokes <= input_len;
                prefix_len <= 5'd1;
                dict_idx <= 0;
                state <= (input_len > 0 && input_len <= MAX_WORD_LEN) ? SETUP_PREFIX : DONE_STATE;
            end
            
            SETUP_PREFIX: begin
                if (prefix_len > input_len) begin
                    state <= DONE_STATE;
                end else begin
                    dict_idx <= 0;
                    state <= SETUP_DICT;
                end
            end
            
            SETUP_DICT: begin
                if (dict_idx >= NUM_DICT_WORDS) begin
                    state <= NEXT_PREFIX;
                end else begin
                    state <= CHECK_PREFIX;
                end
            end
            
            CHECK_PREFIX: begin
                if (prefix_match && dict_lens[dict_idx] > 0) begin
                    state <= CALC_COMMON;
                end else begin
                    state <= NEXT_DICT;
                end
            end
            
            CALC_COMMON: begin
                state <= CALC_COST;
            end
            
            CALC_COST: begin
                cost <= prefix_len + 1 + dict_lens[dict_idx] + input_len - (common_len << 1);
                state <= UPDATE_MIN;
            end
            
            UPDATE_MIN: begin
                if (cost < min_keystrokes) begin
                    min_keystrokes <= cost;
                end
                state <= NEXT_DICT;
            end
            
            NEXT_DICT: begin
                dict_idx <= dict_idx + 1;
                state <= SETUP_DICT;
            end
            
            NEXT_PREFIX: begin
                prefix_len <= prefix_len + 1;
                state <= SETUP_PREFIX;
            end
            
            DONE_STATE: begin
                result <= min_keystrokes;
                done <= 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule