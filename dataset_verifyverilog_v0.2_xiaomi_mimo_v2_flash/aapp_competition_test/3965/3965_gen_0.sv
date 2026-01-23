module syllable_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] pattern,
    input [127:0] line,
    output reg match,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CHECK_CHAR = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [3:0] char_index; // 0 to 15 for 16 characters
    reg [7:0] vowel_count;
    reg [7:0] pattern_reg; // Store pattern locally
    reg [127:0] line_reg;  // Store line locally

    // Combinational logic for character extraction and vowel detection
    wire [7:0] current_char;
    wire is_vowel;

    // Extract current 8-bit character based on char_index
    // Multiplexer to select the correct byte from the 128-bit line
    assign current_char = line_reg[(char_index * 8) +: 8];

    // Vowel detection logic (combinational)
    // Checks lowercase a, e, i, o, u, y
    assign is_vowel = (current_char == 8'h61) || // 'a'
                      (current_char == 8'h65) || // 'e'
                      (current_char == 8'h69) || // 'i'
                      (current_char == 8'h6F) || // 'o'
                      (current_char == 8'h75) || // 'u'
                      (current_char == 8'h79);   // 'y'

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous Reset
            state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
            vowel_count <= 8'b0;
            char_index <= 4'b0;
        end else begin
            // Default outputs to prevent latches and ensure single-cycle pulses
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    vowel_count <= 8'b0;
                    char_index <= 4'b0;
                    match <= 1'b0;
                    if (start) begin
                        state <= CHECK_CHAR;
                        line_reg <= line;          // Capture input data
                        pattern_reg <= pattern;    // Capture target pattern
                    end
                end

                CHECK_CHAR: begin
                    // Increment counter if current character is a vowel
                    if (is_vowel) begin
                        vowel_count <= vowel_count + 1;
                    end

                    // Check if we have processed all 16 characters
                    if (char_index == 4'd15) begin
                        state <= DONE;
                        // We must register the comparison result here for the next state
                        // Or calculate it combinatorially in the DONE state using the final count.
                        // Let's transition to DONE and compare there.
                    end else begin
                        char_index <= char_index + 1;
                    end
                end

                DONE: begin
                    // Compare final count with target pattern
                    // Note: vowel_count has the final value here because the increment for the last char
                    // happened in the previous cycle (CHECK_CHAR state).
                    match <= (vowel_count == pattern_reg);
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
