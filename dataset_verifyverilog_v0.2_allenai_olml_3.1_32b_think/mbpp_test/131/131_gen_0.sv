module reverse_vowels (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

// Internal signals
reg [7:0] char_buffer [7:0];
reg [7:0] vowel_buffer [7:0];
reg [3:0] input_count; // 0 to 7 → 3 bits enough
reg [3:0] vowel_count; // 0 to 8 → 4 bits
reg [2:0] output_index;
reg [3:0] rev_index; // 0 to 7 → 3 bits, but using 4 for safety
reg [1:0] state; // 2 bits
reg [7:0] is_vowel [7:0];
reg done_reg;

// Helper function
function automatic is_vowel_func;
input [7:0] c;
begin
    is_vowel_func = 0;
    if (c == 8'h61 || c ==8'h65 || c ==8'h69 || c ==8'h6F || c ==8'h75 ||
        c ==8'h41 || c ==8'h45 || c ==8'h49 || c ==8'h4F || c ==8'h55)
        is_vowel_func = 1;
endfunction

// Assign done to done_reg
assign done = done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        state <= 2'b00;
        input_count <=4'd0;
        vowel_count <=4'd0;
        output_index <=3'd0;
        rev_index <=4'd0;
        done_reg <=1'b0;
        char_buffer <= {8{8'b0}};
        vowel_buffer <= {8{8'b0}};
        is_vowel <= {8{1'b0}};
        // Also reset outputs?
        char_out <=8'b0;
        valid_out <=1'b0;
    end else begin
        case(state)
            2'b00: // IDLE
                if (start) begin
                    // Transition to COLLECT, reset necessary registers
                    state <= 2'b01;
                    input_count <=4'd0;
                    vowel_count <=4'd0;
                    output_index <=3'd0;
                    rev_index <=4'd0;
                    char_buffer <= {8{8'b0}};
                    vowel_buffer <= {8{8'b0}};
                    is_vowel <= {8{1'b0}};
                end
            endcase
        endcase
    end
end

// Main logic
always @(posedge clk) begin
    if (!rst_n) begin
        char_out <=8'b0;
        valid_out <=1'b0;
    end else begin
        case(state)
            2'b00: // IDLE
                // Do nothing, outputs remain 0
            endcase
            2'b01: // COLLECT_VOWELS
                if (valid_in) begin
                    // Capture the character
                    char_buffer[input_count] <= char_in;
                    is_vowel[input_count] <= is_vowel_func(char_in);
                    if (is_vowel[input_count]) begin
                        vowel_buffer[vowel_count] <= char_in;
                        vowel_count <= vowel_count +1;
                    end
                    input_count <= input_count +1;
                    if (input_count ==8) begin
                        state <= 2'b10; // OUTPUT_CHARS
                        rev_index <= vowel_count -1; // Initialize reverse index
                    end
                end
                // No output generated here; outputs stay at previous values (0)
            endcase
            2'b10: // OUTPUT_CHARS
                if (output_index <8) begin
                    reg [7:0] current_char;
                    if (is_vowel[output_index]) begin
                        current_char = vowel_buffer[rev_index];
                        rev_index <= rev_index -1;
                    end else begin
                        current_char = char_buffer[output_index];
                    end
                    char_out <= current_char;
                    valid_out <=1'b1;
                    output_index <= output_index +1;
                end else begin
                    done_reg <=1'b1;
                    // valid_out will be 0 since condition fails
                end
            endcase
        endcase
    end
end

endmodule