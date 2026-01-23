module reverse_words #(
    parameter MAX_STR_LEN = 16,
    parameter CHAR_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [CHAR_WIDTH-1:0] char_in [0:MAX_STR_LEN-1],
    output reg [CHAR_WIDTH-1:0] char_out [0:MAX_STR_LEN-1],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PARSE     = 3'd1;
    localparam [2:0] REORDER   = 3'd2;
    localparam [2:0] WRITE     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Word storage
    reg [7:0] word_start [0:MAX_STR_LEN];
    reg [7:0] word_end [0:MAX_STR_LEN];
    reg [7:0] word_count;
    
    // Working registers
    reg [7:0] parse_ptr;
    reg [7:0] write_ptr;
    reg [7:0] current_word;
    reg [7:0] char_idx;
    reg [7:0] cycle_count;
    
    // Parameters
    localparam SPACE = 8'h20;
    localparam NULL = 8'h00;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            parse_ptr <= 8'd0;
            write_ptr <= 8'd0;
            current_word <= 8'd0;
            char_idx <= 8'd0;
            word_count <= 8'd0;
            cycle_count <= 8'd0;
            
            for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                char_out[i] <= {CHAR_WIDTH{1'b0}};
                word_start[i] <= 8'd0;
                word_end[i] <= 8'd0;
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE;
                        parse_ptr <= 8'd0;
                        word_count <= 8'd0;
                        current_word <= 8'd0;
                    end
                end
                
                PARSE: begin
                    if (parse_ptr < MAX_STR_LEN && cycle_count < MAX_CYCLES) begin
                        // Skip leading spaces/zeros
                        if (current_word == 0 && 
                           (char_in[parse_ptr] == SPACE || char_in[parse_ptr] == NULL)) begin
                            parse_ptr <= parse_ptr + 8'd1;
                        end
                        // Word start detected
                        else if (current_word == 0 || 
                                (char_in[parse_ptr-1] == SPACE && 
                                 char_in[parse_ptr] != SPACE &&
                                 char_in[parse_ptr] != NULL)) begin
                            word_start[current_word] <= parse_ptr;
                            current_word <= current_word + 8'd1;
                        end
                        // Word end detected
                        if (char_in[parse_ptr] == SPACE || 
                            char_in[parse_ptr] == NULL ||
                            parse_ptr == MAX_STR_LEN-1) begin
                            if (current_word > 0) begin
                                word_end[current_word-1] <= 
                                    (parse_ptr > 0 && char_in[parse_ptr] != SPACE && char_in[parse_ptr] != NULL) 
                                    ? parse_ptr : parse_ptr - 8'd1;
                                word_count <= current_word;
                            end
                        end
                        parse_ptr <= parse_ptr + 8'd1;
                    end else begin
                        state <= REORDER;
                        current_word <= word_count - 8'd1;
                        char_idx <= 8'd0;
                        write_ptr <= 8'd0;
                    end
                end
                
                REORDER: begin
                    if (write_ptr < MAX_STR_LEN && cycle_count < MAX_CYCLES) begin
                        if (current_word < word_count) begin
                            if (char_idx <= (word_end[current_word] - word_start[current_word])) begin
                                char_out[write_ptr] <= char_in[word_start[current_word] + char_idx];
                                write_ptr <= write_ptr + 8'd1;
                                char_idx <= char_idx + 8'd1;
                            end else begin
                                // Insert space between words
                                if (current_word > 0) begin
                                    char_out[write_ptr] <= SPACE;
                                    write_ptr <= write_ptr + 8'd1;
                                end
                                current_word <= current_word - 8'd1;
                                char_idx <= 8'd0;
                            end
                        end else begin
                            // Fill remaining with spaces
                            char_out[write_ptr] <= SPACE;
                            write_ptr <= write_ptr + 8'd1;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
            end
        end
    end
    
endmodule