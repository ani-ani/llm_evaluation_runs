module robber_language_decoder (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [15:0] str_len,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // Constants
    localparam MODULO = 32'd1000009;
    localparam IDLE = 3'b000;
    localparam READING = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam CALCULATING = 3'b011;
    localparam DONE = 3'b100;

    // State machine
    reg [2:0] state = IDLE;
    reg [3:0] char_count = 0;
    reg [3:0] pos = 0;
    reg [31:0] dp_curr = 0;
    reg [31:0] dp_next = 0;
    reg [31:0] dp_prev = 0;
    reg [7:0] char_buffer [0:15];
    reg [3:0] buffer_index = 0;

    // Vowel check (simplified: 'a', 'e', 'i', 'o', 'u')
    function automatic bit is_vowel(input [7:0] c);
        return (c == "a" || c == "e" || c == "i" || c == "o" || c == "u");
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_count <= 0;
            pos <= 0;
            dp_curr <= 0;
            dp_next <= 0;
            dp_prev <= 0;
            buffer_index <= 0;
            result <= 0;
            done <= 0;
            error <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= READING;
                        char_count <= 0;
                        buffer_index <= 0;
                        dp_curr <= 1; // Base case: empty string
                        dp_next <= 0;
                        dp_prev <= 0;
                        done <= 0;
                        error <= 0;
                    end
                end

                READING: begin
                    if (char_count < str_len) begin
                        char_buffer[buffer_index] <= char_in;
                        buffer_index <= buffer_index + 1;
                        char_count <= char_count + 1;
                    end else begin
                        state <= PROCESSING;
                        pos <= 0;
                        dp_curr <= 1; // Reset for processing
                        dp_next <= 0;
                    end
                end

                PROCESSING: begin
                    if (pos < str_len) begin
                        dp_next <= 0;
                        if (is_vowel(char_buffer[pos])) begin
                            dp_next <= dp_curr;
                            pos <= pos + 1;
                        end else begin
                            // Option 1: Untransformed consonant
                            dp_next <= dp_curr;
                            // Option 2: Transformed consonant (C+o+C)
                            if (pos + 2 < str_len && 
                                char_buffer[pos + 1] == "o" && 
                                char_buffer[pos + 2] == char_buffer[pos]) begin
                                dp_next <= (dp_curr + dp_curr) % MODULO;
                                pos <= pos + 3;
                            end else begin
                                pos <= pos + 1;
                            end
                        end
                        dp_curr <= dp_next;
                    end else begin
                        state <= CALCULATING;
                    end
                end

                CALCULATING: begin
                    result <= dp_curr % MODULO;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule