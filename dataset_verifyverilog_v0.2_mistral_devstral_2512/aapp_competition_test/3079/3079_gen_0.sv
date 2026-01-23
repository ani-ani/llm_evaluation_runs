module slavko_word(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [79:0] slavko_word_out,
    output reg [2:0] length_out,
    output reg winnable,
    output reg done
);

    // Define states
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        SETUP,
        MIRKO_PICK,
        SLAVKO_PICK,
        COMPARE,
        DONE_STATE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] buffer [0:7]; // Buffer to store input characters
    reg [3:0] char_count; // Number of characters loaded
    reg [3:0] turn_count; // Number of turns completed
    reg [7:0] mirko_word [0:3]; // Mirko's word (max 4 chars for N=8)
    reg [7:0] slavko_word [0:3]; // Slavko's word (max 4 chars for N=8)
    reg [5:0] freq [0:25]; // Frequency array for 'a' to 'z'
    reg [3:0] buffer_ptr; // Pointer to current buffer position
    reg [3:0] mirko_ptr; // Pointer for Mirko's word
    reg [3:0] slavko_ptr; // Pointer for Slavko's word
    reg [3:0] i; // Loop counter
    reg [7:0] current_char; // Current character being processed
    reg [7:0] min_char; // Minimum character found
    reg [7:0] rightmost_char; // Rightmost character for Mirko
    reg [3:0] rightmost_index; // Index of rightmost character

    // State transition logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            char_count <= 0;
            turn_count <= 0;
            buffer_ptr <= 0;
            mirko_ptr <= 0;
            slavko_ptr <= 0;
            i <= 0;
            current_char <= 0;
            min_char <= 0;
            rightmost_char <= 0;
            rightmost_index <= 0;
            slavko_word_out <= 0;
            length_out <= 0;
            winnable <= 0;
            done <= 0;
            for (int j = 0; j < 8; j++) begin
                buffer[j] <= 0;
            end
            for (int k = 0; k < 26; k++) begin
                freq[k] <= 0;
            end
            for (int m = 0; m < 4; m++) begin
                mirko_word[m] <= 0;
                slavko_word[m] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                if (char_count == 7) begin
                    next_state = SETUP;
                end
            end
            SETUP: begin
                next_state = MIRKO_PICK;
            end
            MIRKO_PICK: begin
                next_state = SLAVKO_PICK;
            end
            SLAVKO_PICK: begin
                if (turn_count == (char_count / 2) - 1) begin
                    next_state = COMPARE;
                end else begin
                    next_state = MIRKO_PICK;
                end
            end
            COMPARE: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // State actions
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state transition
        end else begin
            case (current_state)
                LOAD: begin
                    if (start) begin
                        buffer[buffer_ptr] <= char_in;
                        buffer_ptr <= buffer_ptr + 1;
                        char_count <= char_count + 1;
                    end
                end
                SETUP: begin
                    // Initialize frequency array
                    for (int k = 0; k < 26; k++) begin
                        freq[k] <= 0;
                    end
                    for (int j = 0; j < char_count; j++) begin
                        current_char <= buffer[j];
                        if (current_char >= "a" && current_char <= "z") begin
                            freq[current_char - "a"] <= freq[current_char - "a"] + 1;
                        end
                    end
                    turn_count <= 0;
                    mirko_ptr <= 0;
                    slavko_ptr <= 0;
                end
                MIRKO_PICK: begin
                    // Find rightmost character
                    rightmost_index <= char_count - 1 - turn_count;
                    rightmost_char <= buffer[rightmost_index];
                    mirko_word[mirko_ptr] <= rightmost_char;
                    mirko_ptr <= mirko_ptr + 1;
                    // Decrement frequency
                    if (rightmost_char >= "a" && rightmost_char <= "z") begin
                        freq[rightmost_char - "a"] <= freq[rightmost_char - "a"] - 1;
                    end
                end
                SLAVKO_PICK: begin
                    // Find smallest character
                    min_char <= "z";
                    for (int k = 0; k < 26; k++) begin
                        if (freq[k] > 0 && ("a" + k) < min_char) begin
                            min_char <= "a" + k;
                        end
                    end
                    slavko_word[slavko_ptr] <= min_char;
                    slavko_ptr <= slavko_ptr + 1;
                    // Decrement frequency
                    if (min_char >= "a" && min_char <= "z") begin
                        freq[min_char - "a"] <= freq[min_char - "a"] - 1;
                    end
                    turn_count <= turn_count + 1;
                end
                COMPARE: begin
                    // Compare Slavko's word with Mirko's word
                    winnable <= 0;
                    for (int m = 0; m < 4; m++) begin
                        if (slavko_word[m] < mirko_word[m]) begin
                            winnable <= 1;
                            break;
                        end else if (slavko_word[m] > mirko_word[m]) begin
                            break;
                        end
                    end
                    // Pack Slavko's word into output
                    slavko_word_out <= 0;
                    for (int n = 0; n < 4; n++) begin
                        slavko_word_out[(n+1)*8-1:n*8] <= slavko_word[n];
                    end
                    length_out <= char_count / 2;
                    done <= 1;
                end
                DONE_STATE: begin
                    done <= 0;
                end
            endcase
        end
    end

endmodule