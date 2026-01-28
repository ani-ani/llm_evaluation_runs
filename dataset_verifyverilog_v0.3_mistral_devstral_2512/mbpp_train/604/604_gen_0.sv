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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Internal registers
    reg [CHAR_WIDTH-1:0] temp_in [0:MAX_STR_LEN-1];
    reg [CHAR_WIDTH-1:0] temp_out [0:MAX_STR_LEN-1];
    reg [3:0] word_start [0:MAX_STR_LEN/2-1];
    reg [3:0] word_end [0:MAX_STR_LEN/2-1];
    reg [3:0] word_count;
    reg [3:0] out_index;
    reg [3:0] in_index;
    reg [3:0] word_idx;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                temp_in[i] <= 8'd0;
                temp_out[i] <= 8'd0;
                char_out[i] <= 8'd0;
            end
            
            // Initialize word tracking
            for (i = 0; i < MAX_STR_LEN/2; i = i + 1) begin
                word_start[i] <= 8'd0;
                word_end[i] <= 8'd0;
            end
            
            word_count <= 4'd0;
            out_index <= 4'd0;
            in_index <= 4'd0;
            word_idx <= 4'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    // Copy input to temp_in
                    integer i;
                    for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                        temp_in[i] = char_in[i];
                    end
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                // Find word boundaries
                reg [3:0] current_word;
                reg [3:0] word_start_idx;
                reg [3:0] word_end_idx;
                reg [3:0] i;
                reg [3:0] j;
                
                current_word = 4'd0;
                word_start_idx = 4'd0;
                word_end_idx = 4'd0;
                
                // Find all words
                for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                    if (temp_in[i] == 8'd32 || temp_in[i] == 8'd0) begin
                        if (word_start_idx != word_end_idx) begin
                            word_start[current_word] = word_start_idx;
                            word_end[current_word] = word_end_idx;
                            current_word = current_word + 4'd1;
                        end
                        word_start_idx = i + 4'd1;
                        word_end_idx = i + 4'd1;
                    end else begin
                        word_end_idx = i + 4'd1;
                    end
                end
                
                // Last word if not space-terminated
                if (word_start_idx != word_end_idx && word_end_idx != 4'd0) begin
                    word_start[current_word] = word_start_idx;
                    word_end[current_word] = word_end_idx;
                    current_word = current_word + 4'd1;
                end
                
                word_count = current_word;
                
                // Reverse words
                for (i = 0; i < word_count; i = i + 1) begin
                    j = word_count - 4'd1 - i;
                    
                    // Copy word from end to beginning
                    reg [3:0] src_start;
                    reg [3:0] src_end;
                    reg [3:0] dest_start;
                    reg [3:0] k;
                    
                    src_start = word_start[j];
                    src_end = word_end[j];
                    dest_start = out_index;
                    
                    for (k = src_start; k < src_end; k = k + 1) begin
                        temp_out[dest_start] = temp_in[k];
                        dest_start = dest_start + 4'd1;
                    end
                    
                    // Add space if not last word
                    if (i != word_count - 4'd1) begin
                        temp_out[dest_start] = 8'd32;
                        dest_start = dest_start + 4'd1;
                    end
                    
                    out_index = dest_start;
                end
                
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                // Copy to output
                integer i;
                for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                    char_out[i] = temp_out[i];
                end
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state == PROCESS) begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state = IDLE;
            end
        end else begin
            cycle_count <= 8'd0;
        end
    end

endmodule