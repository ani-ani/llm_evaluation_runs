module WordRemover (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] K,
    input wire [7:0] char_in,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] READING  = 3'd1;
    localparam [2:0] PARSING  = 3'd2;
    localparam [2:0] OUTPUTTING = 3'd3;
    localparam [2:0] WAITING  = 3'd4;
    localparam [2:0] FINISH   = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [6:0] read_counter;      // 0-63 cycles for reading
    reg [6:0] parse_counter;     // Track position in output_buffer
    reg [4:0] word_len_counter;  // 0-15 for word length
    reg [4:0] output_index;      // 0-63 for output
    reg [4:0] output_count;      // Total characters to output
    reg [7:0] char_buffer [0:15]; // Current word buffer
    reg [7:0] output_buffer [0:63]; // Result storage
    reg skip_word_flag;          // Flag to skip current word
    reg space_needed;            // Flag for space between words
    reg input_done;              // Input collection complete
    reg [2:0] i;                 // Loop variable for reset
    
    // Wire declarations for combinational logic
    wire is_space;
    wire is_word_end;
    wire word_len_match;
    
    assign is_space = (char_in == 8'h20);
    assign is_word_end = (char_in == 8'h20) || (read_counter == 6'd63);
    assign word_len_match = (word_len_counter[3:0] == K);

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_valid <= 1'b0;
            char_out <= 8'd0;
            read_counter <= 7'd0;
            parse_counter <= 7'd0;
            word_len_counter <= 5'd0;
            output_index <= 5'd0;
            output_count <= 5'd0;
            skip_word_flag <= 1'b0;
            space_needed <= 1'b0;
            input_done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 8'd0;
            end
            for (i = 0; i < 64; i = i + 1) begin
                output_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_valid <= 1'b0;
                    read_counter <= 7'd0;
                    parse_counter <= 7'd0;
                    word_len_counter <= 5'd0;
                    output_index <= 5'd0;
                    output_count <= 5'd0;
                    skip_word_flag <= 1'b0;
                    space_needed <= 1'b0;
                    input_done <= 1'b0;
                    // Clear buffers
                    for (i = 0; i < 16; i = i + 1) begin
                        char_buffer[i] <= 8'd0;
                    end
                    for (i = 0; i < 64; i = i + 1) begin
                        output_buffer[i] <= 8'd0;
                    end
                end
                
                READING: begin
                    // Store character in buffer
                    if (read_counter < 64) begin
                        read_counter <= read_counter + 7'd1;
                    end
                    // Process character
                    if (is_space) begin
                        // Space encountered - process word
                        if (word_len_match) begin
                            skip_word_flag <= 1'b1; // Skip this word
                        end else if (word_len_counter > 0) begin
                            // Add word to output
                            // Use loop for unpacked array assignment
                            if (word_len_counter <= 5'd16) begin
                                // For Icarus Verilog compatibility, use sequential assignment
                                if (word_len_counter >= 5'd1) output_buffer[parse_counter] <= char_buffer[0];
                                if (word_len_counter >= 5'd2) output_buffer[parse_counter + 7'd1] <= char_buffer[1];
                                if (word_len_counter >= 5'd3) output_buffer[parse_counter + 7'd2] <= char_buffer[2];
                                if (word_len_counter >= 5'd4) output_buffer[parse_counter + 7'd3] <= char_buffer[3];
                                if (word_len_counter >= 5'd5) output_buffer[parse_counter + 7'd4] <= char_buffer[4];
                                if (word_len_counter >= 5'd6) output_buffer[parse_counter + 7'd5] <= char_buffer[5];
                                if (word_len_counter >= 5'd7) output_buffer[parse_counter + 7'd6] <= char_buffer[6];
                                if (word_len_counter >= 5'd8) output_buffer[parse_counter + 7'd7] <= char_buffer[7];
                                if (word_len_counter >= 5'd9) output_buffer[parse_counter + 7'd8] <= char_buffer[8];
                                if (word_len_counter >= 5'd10) output_buffer[parse_counter + 7'd9] <= char_buffer[9];
                                if (word_len_counter >= 5'd11) output_buffer[parse_counter + 7'd10] <= char_buffer[10];
                                if (word_len_counter >= 5'd12) output_buffer[parse_counter + 7'd11] <= char_buffer[11];
                                if (word_len_counter >= 5'd13) output_buffer[parse_counter + 7'd12] <= char_buffer[12];
                                if (word_len_counter >= 5'd14) output_buffer[parse_counter + 7'd13] <= char_buffer[13];
                                if (word_len_counter >= 5'd15) output_buffer[parse_counter + 7'd14] <= char_buffer[14];
                                if (word_len_counter == 5'd16) output_buffer[parse_counter + 7'd15] <= char_buffer[15];
                            end
                            output_count <= output_count + word_len_counter;
                            parse_counter <= parse_counter + word_len_counter;
                            space_needed <= 1'b1; // Add space after word
                        end
                        word_len_counter <= 5'd0;
                    end else begin
                        // Character is part of word
                        if (word_len_counter < 5'd16) begin
                            char_buffer[word_len_counter] <= char_in;
                            word_len_counter <= word_len_counter + 5'd1;
                        end else begin
                            // Word too long - treat as skip
                            skip_word_flag <= 1'b1;
                        end
                    end
                    input_done <= (read_counter == 6'd63);
                end
                
                PARSING: begin
                    // Process final word if exists
                    if (word_len_counter > 0 && !skip_word_flag) begin
                        if (!word_len_match) begin
                            // Add last word (no trailing space)
                            if (word_len_counter <= 5'd16) begin
                                if (word_len_counter >= 5'd1) output_buffer[parse_counter] <= char_buffer[0];
                                if (word_len_counter >= 5'd2) output_buffer[parse_counter + 7'd1] <= char_buffer[1];
                                if (word_len_counter >= 5'd3) output_buffer[parse_counter + 7'd2] <= char_buffer[2];
                                if (word_len_counter >= 5'd4) output_buffer[parse_counter + 7'd3] <= char_buffer[3];
                                if (word_len_counter >= 5'd5) output_buffer[parse_counter + 7'd4] <= char_buffer[4];
                                if (word_len_counter >= 5'd6) output_buffer[parse_counter + 7'd5] <= char_buffer[5];
                                if (word_len_counter >= 5'd7) output_buffer[parse_counter + 7'd6] <= char_buffer[6];
                                if (word_len_counter >= 5'd8) output_buffer[parse_counter + 7'd7] <= char_buffer[7];
                                if (word_len_counter >= 5'd9) output_buffer[parse_counter + 7'd8] <= char_buffer[8];
                                if (word_len_counter >= 5'd10) output_buffer[parse_counter + 7'd9] <= char_buffer[9];
                                if (word_len_counter >= 5'd11) output_buffer[parse_counter + 7'd10] <= char_buffer[10];
                                if (word_len_counter >= 5'd12) output_buffer[parse_counter + 7'd11] <= char_buffer[11];
                                if (word_len_counter >= 5'd13) output_buffer[parse_counter + 7'd12] <= char_buffer[12];
                                if (word_len_counter >= 5'd14) output_buffer[parse_counter + 7'd13] <= char_buffer[13];
                                if (word_len_counter >= 5'd15) output_buffer[parse_counter + 7'd14] <= char_buffer[14];
                                if (word_len_counter == 5'd16) output_buffer[parse_counter + 7'd15] <= char_buffer[15];
                            end
                            output_count <= output_count + word_len_counter;
                            parse_counter <= parse_counter + word_len_counter;
                            space_needed <= 1'b0; // No space after last word
                        end
                    end
                    output_index <= 5'd0;
                end
                
                OUTPUTTING: begin
                    out_valid <= 1'b0;
                    if (output_index < output_count) begin
                        char_out <= output_buffer[output_index];
                        output_index <= output_index + 5'd1;
                        out_valid <= 1'b1;
                    end
                end
                
                WAITING: begin
                    out_valid <= 1'b0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    out_valid <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = READING;
                else
                    next_state = IDLE;
            end
            
            READING: begin
                if (read_counter >= 6'd63) begin
                    next_state = PARSING;
                end else begin
                    next_state = READING;
                end
            end
            
            PARSING: begin
                if (output_count > 5'd0)
                    next_state = OUTPUTTING;
                else
                    next_state = FINISH;
            end
            
            OUTPUTTING: begin
                if (output_index < output_count) begin
                    next_state = WAITING; // Wait one cycle between outputs
                end else begin
                    next_state = FINISH;
                end
            end
            
            WAITING: begin
                next_state = OUTPUTTING;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule