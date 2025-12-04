module quote_extractor (
    input clk,
    input rst_n,
    input start,
    input [63:0][7:0] text_input,  // 64 bytes input
    output reg [7:0][15:0][7:0] extracted_strings, // 8 slots of 16-byte strings
    output reg [2:0] string_count,   // 0-7 valid strings
    output reg done                  // processing complete
);

// State machine: 0=IDLE (outside quotes), 1=CAPTURING (inside quotes)
reg [1:0] state;
reg [2:0] str_idx;      // current string slot (0-7)
reg [3:0] char_idx;     // position in current string (0-15)
reg [5:0] byte_counter; // processed bytes (0-63)
reg [7:0] current_string [15:0]; // temporary storage for current string

integer i, j; // loop variables

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'b0;
        str_idx <= 3'b0;
        char_idx <= 4'b0;
        byte_counter <= 6'b0;
        done <= 1'b0;
        string_count <= 3'b0;
        
        // Clear outputs
        for (i=0; i<8; i++) begin
            for (j=0; j<16; j++) begin
                extracted_strings[i][j] <= 8'b0;
            end
        end
        
        // Clear temporary string
        for (i=0; i<16; i++) begin
            current_string[i] <= 8'b0;
        end
    end
    else if (start) begin
        if (!done) begin
            case (state)
                0: begin // IDLE state
                    if (text_input[byte_counter] == 8'h22) begin // double quote found
                        // Start capturing new string
                        for (i=0; i<16; i++) begin
                            current_string[i] <= 8'b0;
                        end
                        char_idx <= 4'b0;
                        state <= 1;
                    end
                end
                
                1: begin // CAPTURING state
                    if (text_input[byte_counter] == 8'h22) begin // closing quote
                        // Store the captured string
                        if (str_idx < 7) begin // only 7 slots valid (0-6)
                            extracted_strings[str_idx] <= current_string;
                            str_idx <= str_idx + 1;
                        end
                        
                        // Reset for next string
                        char_idx <= 4'b0;
                        state <= 0;
                    end
                    else begin // normal character
                        if (char_idx < 16) begin // truncate at 16 chars
                            current_string[char_idx] <= text_input[byte_counter];
                            char_idx <= char_idx + 1;
                        end
                    end
                end
            endcase
            
            // Update byte counter and check completion conditions
            if (byte_counter == 6'd63) begin // end of 64-byte input
                done <= 1'b1;
                string_count <= str_idx;
                byte_counter <= byte_counter; // hold at 63
            end
            else if (str_idx == 3'd7) begin // max 7 strings collected
                done <= 1'b1;
                string_count <= 3'd7;
                byte_counter <= byte_counter; // hold current count
            end
            else begin
                byte_counter <= byte_counter + 1;
            end
        end
    end
end

endmodule