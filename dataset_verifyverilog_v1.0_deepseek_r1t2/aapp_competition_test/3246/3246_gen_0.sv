module decipher (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] string_in,
    input wire [511:0] dict_words,
    input wire [31:0] dict_lengths,
    output reg done,
    output reg [1:0] result_status,
    output reg [255:0] result_sentence
);

    // State declarations
    localparam [2:0] IDLE      = 3'b000;
    localparam [2:0] PRECOMPUTE = 3'b001;
    localparam [2:0] SEARCH    = 3'b010;
    localparam [2:0] RESULT    = 3'b011;
    reg [2:0] state, next_state;

    // Word signature storage
    reg [3:0] word_length [0:7];
    reg [7:0] first_char [0:7];
    reg [7:0] last_char [0:7];
    reg [127:0] internal_multiset [0:7];

    // Search variables
    reg [4:0] string_pos;
    reg [2:0] word_idx;
    reg [2:0] segmentation_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Helper function: compute multiset
    function [127:0] compute_multiset(input [3:0] length, input [63:0] word);
        integer i;
        reg [7:0] c;
        begin
            compute_multiset = 128'd0;
            if (length > 3'd2) begin
                for (i = 1; i < length - 1; i = i + 1) begin
                    c = word[(i*8)+:8];
                    if (c >= 8'h61 && c <= 8'h7a) begin
                        compute_multiset[(c-8'h61)*5 +:5] = compute_multiset[(c-8'h61)*5 +:5] + 5'd1;
                    end
                end
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_status <= 2'b00;
            result_sentence <= 256'd0;
            string_pos <= 5'd0;
            word_idx <= 3'd0;
            segmentation_count <= 3'd0;
            cycle_count <= 8'd0;
            // Initialize arrays
            begin
                integer i;
                for (i = 0; i < 8; i = i + 1) begin
                    word_length[i] <= 4'd0;
                    first_char[i] <= 8'd0;
                    last_char[i] <= 8'd0;
                    internal_multiset[i] <= 128'd0;
                end
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    segmentation_count <= 3'd0;
                    string_pos <= 5'd0;
                    if (start) cycle_count <= 8'd0;
                end
                
                PRECOMPUTE: begin
                    if (word_idx < 3'd7) begin
                        word_length[word_idx] <= dict_lengths[(word_idx*4)+:4];
                        first_char[word_idx] <= dict_words[(word_idx*64)+:8];
                        last_char[word_idx]  <= dict_words[word_idx*64 + (dict_lengths[(word_idx*4)+:4]-1)*8 +:8];
                        internal_multiset[word_idx] <= compute_multiset(dict_lengths[(word_idx*4)+:4], dict_words[word_idx*64+:64]);
                        word_idx <= word_idx + 3'd1;
                    end
                end
                
                SEARCH: begin
                    if (string_pos < 5'd31 && word_idx < 3'd8) begin
                        // Simplified matching check
                        if (word_length[word_idx] != 4'd0 &&
                            (string_pos + {1'b0, word_length[word_idx]} <= 5'd32) &&
                            (first_char[word_idx] == string_in[(string_pos*8)+:8]) &&
                            (last_char[word_idx] == string_in[((string_pos + word_length[word_idx] - 1)*8)+:8])) begin

                            // Placeholder for multiset check
                            if (string_pos + word_length[word_idx] == 5'd32) begin
                                segmentation_count <= segmentation_count + 3'd1;
                            end
                        end
                        word_idx <= word_idx + 3'd1;
                    end else if (word_idx == 3'd8 || cycle_count >= MAX_CYCLES) begin
                        string_pos <= string_pos + 5'd1;
                        word_idx <= 3'd0;
                    end
                end
                
                RESULT: begin
                    done <= 1'b1;
                    case (segmentation_count)
                        3'd0: begin
                            result_status <= 2'b01;
                            result_sentence <= {8"impossible", 224'd0};
                        end
                        3'd1: begin
                            result_status <= 2'b00;
                            result_sentence <= {8"valid    ", 224'd0};
                        end
                        default: begin
                            result_status <= 2'b10;
                            result_sentence <= {8"ambiguous", 224'd0};
                        end
                    endcase
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:      if (start) next_state = PRECOMPUTE;
            PRECOMPUTE: if (word_idx >= 3'd7 || cycle_count >= MAX_CYCLES) next_state = SEARCH;
            SEARCH:    if (string_pos >= 5'd31 || cycle_count >= MAX_CYCLES) next_state = RESULT;
            RESULT:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
endmodule