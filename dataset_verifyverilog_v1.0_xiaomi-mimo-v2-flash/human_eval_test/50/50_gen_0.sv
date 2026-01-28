module caesar_decode (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][7:0] input_string,
    output reg [15:0][7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] DECODE = 2'd1;
    localparam [1:0] DONE   = 2'd2;

    reg [1:0] state, next_state;
    reg [4:0] char_index; // 0 to 15
    reg [7:0] decoded_char;
    reg [7:0] temp_subtract;
    reg [7:0] temp_subtract_signed;

    // ASCII constants
    localparam [7:0] CHAR_A = 8'd97;
    localparam [7:0] CHAR_Z = 8'd122;
    localparam [7:0] SHIFT  = 5'd5;
    localparam [7:0] ALPHABET_SIZE = 8'd26;

    // Sequential logic for state and registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            char_index <= 5'd0;
            // Initialize all result bytes to 0
            result[0] <= 8'd0; result[1] <= 8'd0; result[2] <= 8'd0; result[3] <= 8'd0;
            result[4] <= 8'd0; result[5] <= 8'd0; result[6] <= 8'd0; result[7] <= 8'd0;
            result[8] <= 8'd0; result[9] <= 8'd0; result[10] <= 8'd0; result[11] <= 8'd0;
            result[12] <= 8'd0; result[13] <= 8'd0; result[14] <= 8'd0; result[15] <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        char_index <= 5'd0;
                    end
                end

                DECODE: begin
                    // Decode current character based on pre-calculated arithmetic
                    // Formula: (input - 'a' - 5) mod 26 + 'a'
                    // To handle negative: if < 0, add 26
                    if (temp_subtract_signed[7]) begin // Check if negative (MSB set)
                        // Use temp_subtract which holds (input - 'a' - 5)
                        // Since it's signed negative, we need to add 26 in signed math context
                        // temp_subtract is unsigned 8-bit, but represents a negative value logic
                        // value = temp_subtract + 26
                        decoded_char <= temp_subtract + ALPHABET_SIZE + CHAR_A;
                    end else begin
                        // Positive or zero
                        decoded_char <= temp_subtract + CHAR_A;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Store the decoded character at the current index
                    result[char_index] <= decoded_char;
                    char_index <= char_index + 5'd1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for next state and arithmetic
    always @(*) begin
        // Default assignments
        next_state = state;
        temp_subtract = 8'd0;
        temp_subtract_signed = 8'd0;

        case (state)
            IDLE: begin
                if (start) next_state = DECODE;
                else next_state = IDLE;
            end

            DECODE: begin
                // Calculate: input - 'a' - 5
                // This needs to be signed for the wrap-around check (handled in seq logic via MSB)
                // temp_subtract stores the raw (input - 97 - 5) result
                temp_subtract = input_string[char_index] - CHAR_A - SHIFT;
                
                // We need a signed version to detect negativity
                temp_subtract_signed = input_string[char_index] - CHAR_A - SHIFT;

                // Always transition to DONE in the next cycle
                next_state = DONE;
            end

            DONE: begin
                // If we have processed all 16 characters, return to IDLE
                if (char_index == 5'd15) begin
                    next_state = IDLE;
                end else begin
                    // Process next character
                    next_state = DECODE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule