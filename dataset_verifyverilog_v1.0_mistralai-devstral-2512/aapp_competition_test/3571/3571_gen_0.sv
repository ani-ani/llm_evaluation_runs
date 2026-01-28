module ancient_viewport(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] W,
    input wire [3:0] H,
    input wire [5:0] F,
    input wire [4:0] N,
    input wire [4:0] input_ram_addr,
    input wire [79:0] input_ram_data,
    input wire input_ram_write,
    output reg [7:0] output_char,
    output reg output_valid,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PARSE_WORDS = 4'd1;
    localparam [3:0] WRAP_LINES = 4'd2;
    localparam [3:0] CALC_SCROLL = 4'd3;
    localparam [3:0] RENDER = 4'd4;
    
    reg [3:0] state, next_state;
    
    // Internal RAM for text lines
    reg [79:0] text_ram [0:31];
    reg [4:0] ram_write_ptr;
    reg ram_write_pending;
    
    // Word parsing variables
    reg [7:0] current_word [0:19];
    reg [4:0] word_length;
    reg [4:0] word_ptr;
    reg [4:0] line_ptr;
    reg [4:0] char_ptr;
    reg in_word;
    
    // Wrapped lines buffer
    reg [7:0] wrapped_lines [0:63][0:19];
    reg [5:0] wrapped_line_count;
    reg [4:0] current_wrapped_line;
    reg [4:0] current_wrapped_char;
    
    // Scrollbar variables
    reg [5:0] L;
    reg [5:0] T;
    
    // Rendering variables
    reg [4:0] render_line;
    reg [4:0] render_char;
    reg [4:0] render_state;
    reg [7:0] render_buffer [0:79];
    reg [4:0] render_buffer_ptr;
    
    // Cycle counter for safety
    reg [14:0] cycle_count;
    localparam [14:0] MAX_CYCLES = 15'd20000;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            output_char <= 8'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
            
            // Initialize RAM
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                text_ram[i] <= 80'd0;
            end
            ram_write_ptr <= 5'd0;
            ram_write_pending <= 1'b0;
            
            // Initialize word parsing
            for (i = 0; i < 20; i = i + 1) begin
                current_word[i] <= 8'd0;
            end
            word_length <= 5'd0;
            word_ptr <= 5'd0;
            line_ptr <= 5'd0;
            char_ptr <= 5'd0;
            in_word <= 1'b0;
            
            // Initialize wrapped lines
            for (i = 0; i < 64; i = i + 1) begin
                integer j;
                for (j = 0; j < 20; j = j + 1) begin
                    wrapped_lines[i][j] <= 8'd0;
                end
            end
            wrapped_line_count <= 6'd0;
            current_wrapped_line <= 5'd0;
            current_wrapped_char <= 5'd0;
            
            // Initialize scrollbar
            L <= 6'd0;
            T <= 6'd0;
            
            // Initialize rendering
            render_line <= 5'd0;
            render_char <= 5'd0;
            render_state <= 5'd0;
            for (i = 0; i < 80; i = i + 1) begin
                render_buffer[i] <= 8'd0;
            end
            render_buffer_ptr <= 5'd0;
            
            cycle_count <= 15'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    
                    // Handle RAM writes
                    if (input_ram_write) begin
                        text_ram[input_ram_addr] <= input_ram_data;
                    end
                    
                    if (start) begin
                        next_state <= PARSE_WORDS;
                        line_ptr <= 5'd0;
                        char_ptr <= 5'd0;
                        word_length <= 5'd0;
                        word_ptr <= 5'd0;
                        in_word <= 1'b0;
                        wrapped_line_count <= 6'd0;
                        current_wrapped_line <= 5'd0;
                        current_wrapped_char <= 5'd0;
                        cycle_count <= 15'd0;
                    end
                end
                
                PARSE_WORDS: begin
                    // Parse words from text_ram
                    if (line_ptr < N) begin
                        if (char_ptr < 80) begin
                            reg [7:0] current_char = text_ram[line_ptr][(char_ptr + 1) * 8 - 1: char_ptr * 8];
                            
                            if (current_char == 8'd32) begin
                                // Space: end of word
                                if (in_word) begin
                                    // Store word
                                    integer i;
                                    for (i = 0; i < word_length; i = i + 1) begin
                                        wrapped_lines[current_wrapped_line][i] <= current_word[i];
                                    end
                                    
                                    // Update line wrapping
                                    if (current_wrapped_char + word_length > W) begin
                                        current_wrapped_line <= current_wrapped_line + 1;
                                        current_wrapped_char <= 5'd0;
                                    end else begin
                                        current_wrapped_char <= current_wrapped_char + word_length;
                                    end
                                    
                                    // Reset word
                                    word_length <= 5'd0;
                                    word_ptr <= 5'd0;
                                    in_word <= 1'b0;
                                end
                            end else begin
                                // Character: add to word
                                if (word_length < W) begin
                                    current_word[word_length] <= current_char;
                                    word_length <= word_length + 1;
                                    in_word <= 1'b1;
                                end
                            end
                            
                            char_ptr <= char_ptr + 1;
                        end else begin
                            // End of line
                            char_ptr <= 5'd0;
                            line_ptr <= line_ptr + 1;
                        end
                    end else begin
                        // All lines processed
                        next_state <= WRAP_LINES;
                    end
                    
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                WRAP_LINES: begin
                    // Finalize wrapped lines
                    L <= wrapped_line_count;
                    next_state <= CALC_SCROLL;
                    
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                CALC_SCROLL: begin
                    // Calculate scrollbar thumb position
                    if (L > H) begin
                        T <= ((H - 3) * F) / (L - H);
                    end else begin
                        T <= 6'd0;
                    end
                    
                    next_state <= RENDER;
                    render_line <= 5'd0;
                    render_char <= 5'd0;
                    render_state <= 5'd0;
                    
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                RENDER: begin
                    // Render viewport
                    case (render_state)
                        0: begin
                            // Top border
                            if (render_char < W) begin
                                output_char <= 8'd45; // '-'
                                output_valid <= 1'b1;
                                render_char <= render_char + 1;
                            end else begin
                                output_char <= 8'd10; // newline
                                output_valid <= 1'b1;
                                render_char <= 5'd0;
                                render_state <= 1;
                            end
                        end
                        1: begin
                            // Visible lines
                            if (render_line < H) begin
                                reg [4:0] visible_line = F + render_line;
                                
                                if (render_char < W) begin
                                    if (render_char < 80 && visible_line < L) begin
                                        output_char <= wrapped_lines[visible_line][render_char];
                                    end else begin
                                        output_char <= 8'd32; // space
                                    end
                                    output_valid <= 1'b1;
                                    render_char <= render_char + 1;
                                end else begin
                                    // Scrollbar
                                    if (render_line == 0) begin
                                        output_char <= 8'd94; // '^'
                                    end else if (render_line == H - 1) begin
                                        output_char <= 8'd118; // 'v'
                                    end else if (render_line == H - 4 + T) begin
                                        output_char <= 8'd88; // 'X'
                                    end else begin
                                        output_char <= 8'd32; // space
                                    end
                                    output_valid <= 1'b1;
                                    
                                    output_char <= 8'd10; // newline
                                    output_valid <= 1'b1;
                                    render_char <= 5'd0;
                                    render_line <= render_line + 1;
                                end
                            end else begin
                                // Bottom border
                                if (render_char < W) begin
                                    output_char <= 8'd45; // '-'
                                    output_valid <= 1'b1;
                                    render_char <= render_char + 1;
                                end else begin
                                    output_char <= 8'd10; // newline
                                    output_valid <= 1'b1;
                                    done <= 1'b1;
                                    next_state <= IDLE;
                                end
                            end
                        end
                        default: begin
                            next_state <= IDLE;
                        end
                    endcase
                    
                    cycle_count <= cycle_count + 1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
    
    // Default assignments
    always @(*) begin
        if (state == IDLE) begin
            output_valid = 1'b0;
            done = 1'b0;
        end
    end

endmodule