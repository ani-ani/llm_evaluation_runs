module quotation_extractor (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [5:0] char_index,
    output reg [7:0] extracted [0:7],
    output reg [3:0] extracted_count,
    output reg done,
    output reg error
);

    // Internal state definitions
    typedef enum logic [1:0] {
        IDLE,
        SCANNING,
        CAPTURING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg quote_state; // 1 if inside quotes
    reg [2:0] substring_index; // Current substring being captured (0-7)
    reg [3:0] char_pos; // Position within current substring (0-15)
    reg [7:0] buffer [0:15]; // Temporary buffer for current substring

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            quote_state <= 0;
            substring_index <= 0;
            char_pos <= 0;
            extracted_count <= 0;
            done <= 0;
            error <= 0;
            for (int i = 0; i < 8; i++) begin
                extracted[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = SCANNING;
            end
            SCANNING: begin
                if (char_index == 63) next_state = DONE;
                else if (char_in == 34 && !quote_state) next_state = CAPTURING;
            end
            CAPTURING: begin
                if (char_in == 34) next_state = SCANNING;
                else if (char_index == 63) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quote_state <= 0;
            substring_index <= 0;
            char_pos <= 0;
            for (int i = 0; i < 16; i++) begin
                buffer[i] <= 0;
            end
        end else if (current_state == SCANNING || current_state == CAPTURING) begin
            // Handle quote detection
            if (char_in == 34) begin
                if (!quote_state) begin
                    // Start of new substring
                    quote_state <= 1;
                    char_pos <= 0;
                    if (substring_index == 7) begin
                        error <= 1; // More than 8 substrings
                    end else begin
                        substring_index <= substring_index + 1;
                    end
                end else begin
                    // End of current substring
                    quote_state <= 0;
                    // Store the captured substring
                    for (int i = 0; i < 16; i++) begin
                        if (i < char_pos) begin
                            extracted[substring_index][i*8 +: 8] <= buffer[i];
                        end else begin
                            extracted[substring_index][i*8 +: 8] <= 0;
                        end
                    end
                    extracted_count <= substring_index + 1;
                end
            end else if (quote_state) begin
                // Inside quotes, capture character
                if (char_pos < 16) begin
                    buffer[char_pos] <= char_in;
                    char_pos <= char_pos + 1;
                end else begin
                    error <= 1; // Substring exceeds 16 chars
                end
            end
        end
    end

    // Done signal and error handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            error <= 0;
        end else begin
            if (current_state == DONE) begin
                done <= 1;
                if (quote_state) error <= 1; // Unmatched quote at end
            end else begin
                done <= 0;
            end
        end
    end

endmodule