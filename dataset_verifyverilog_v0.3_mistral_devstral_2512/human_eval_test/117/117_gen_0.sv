module word_selector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    input wire [3:0] n,
    output reg [7:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SCANNING  = 3'd1;
    localparam [2:0] CHECKING  = 3'd2;
    localparam [2:0] FOUND     = 3'd3;
    localparam [2:0] FINISHED  = 3'd4;

    reg [2:0] state;
    reg [3:0] i;                   // Index for scanning
    reg [3:0] j;                   // Index for current word
    reg [3:0] consonant_count;     // Count of consonants in current word
    reg [7:0] current_word [0:15]; // Temporary buffer for current word
    reg in_word;                   // Flag indicating if currently in a word
    reg [7:0] current_char;       // Current character being processed
    reg is_consonant;              // Flag for consonant detection

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            consonant_count <= 4'd0;
            in_word <= 1'b0;
            current_char <= 8'd0;
            is_consonant <= 1'b0;
            done <= 1'b0;
            // Initialize result and current_word arrays
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                result[k] <= 8'd0;
                current_word[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SCANNING;
                        i <= 4'd0;
                        j <= 4'd0;
                        consonant_count <= 4'd0;
                        in_word <= 1'b0;
                        // Clear current_word buffer
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            current_word[k] <= 8'd0;
                        end
                    end
                end

                SCANNING: begin
                    if (i < 4'd16) begin
                        current_char <= str[i];
                        // Check if current character is a space
                        if (current_char == 8'd32) begin
                            if (in_word) begin
                                state <= CHECKING;
                            end
                            in_word <= 1'b0;
                        end else begin
                            // Check if it's a letter
                            if ((current_char >= 8'd65 && current_char <= 8'd90) || (current_char >= 8'd97 && current_char <= 8'd122)) begin
                                // Check if it's a vowel (case insensitive)
                                if (current_char == 8'd65 || current_char == 8'd97 ||  // A,a
                                    current_char == 8'd69 || current_char == 8'd101 || // E,e
                                    current_char == 8'd73 || current_char == 8'd105 || // I,i
                                    current_char == 8'd79 || current_char == 8'd111 || // O,o
                                    current_char == 8'd85 || current_char == 8'd117)   // U,u
                                begin
                                    is_consonant <= 1'b0;
                                end else begin
                                    is_consonant <= 1'b1;
                                    consonant_count <= consonant_count + 4'd1;
                                end
                                // Store character in current_word buffer
                                current_word[j] <= current_char;
                                j <= j + 4'd1;
                                in_word <= 1'b1;
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (in_word) begin
                            state <= CHECKING;
                        end else begin
                            state <= FINISHED;
                        end
                    end
                end

                CHECKING: begin
                    if (consonant_count == n) begin
                        state <= FOUND;
                    end else begin
                        // Clear current_word buffer and reset counters
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            current_word[k] <= 8'd0;
                        end
                        j <= 4'd0;
                        consonant_count <= 4'd0;
                        in_word <= 1'b0;
                        state <= SCANNING;
                    end
                end

                FOUND: begin
                    // Copy current_word to result
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        if (k < j) begin
                            result[k] <= current_word[k];
                        end else begin
                            result[k] <= 8'd32; // Space
                        end
                    end
                    done <= 1'b1;
                    state <= FINISHED;
                end

                FINISHED: begin
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule