module sum_of_digits (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] num_count,
    input wire [63:0] str_data [0:7],
    output reg [15:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam PARSE_CHAR = 3'b001;
    localparam NEXT_CHAR = 3'b010;
    localparam NEXT_NUMBER = 3'b011;
    localparam DONE = 3'b100;

    // Internal Registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [2:0] current_num_index;
    reg [2:0] current_char_index;
    reg [15:0] running_sum;
    reg [7:0] temp_sum;

    // Helper wires for ASCII extraction
    // str_data is array of 8 elements, each 64-bit. 
    // We access str_data[current_num_index][current_char_index*8 +: 8]
    wire [7:0] current_byte;
    assign current_byte = str_data[current_num_index][current_char_index*8 +: 8];

    // Logic for next state and outputs
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = PARSE_CHAR;
                else next_state = IDLE;
            end
            
            PARSE_CHAR: begin
                // Check if valid digit
                if (current_byte >= 8'h30 && current_byte <= 8'h39) begin
                    next_state = NEXT_CHAR;
                end else begin
                    next_state = NEXT_CHAR; // Still move to next char on non-digit
                end
            end

            NEXT_CHAR: begin
                if (current_char_index < 3'b111) begin
                    next_state = PARSE_CHAR;
                end else begin
                    next_state = NEXT_NUMBER;
                end
            end

            NEXT_NUMBER: begin
                // num_count is 8-bit, but index is 3-bit (max 8). 
                // If (current_num_index + 1) < num_count, continue.
                // Since num_count can be up to 8, we compare index < count - 1
                if (num_count == 0) next_state = DONE; // Edge case if start with 0 count
                else if (current_num_index < num_count - 1) begin
                    next_state = PARSE_CHAR;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            current_num_index <= 3'b0;
            current_char_index <= 3'b0;
            running_sum <= 16'b0;
            temp_sum <= 8'b0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_num_index <= 3'b0;
                        current_char_index <= 3'b0;
                        running_sum <= 16'b0;
                        temp_sum <= 8'b0;
                    end
                end

                PARSE_CHAR: begin
                    if (current_byte >= 8'h30 && current_byte <= 8'h39) begin
                        // Add to temporary sum for current number
                        temp_sum <= temp_sum + (current_byte - 8'h30);
                    end
                end

                NEXT_CHAR: begin
                    // Move to next character
                    current_char_index <= current_char_index + 1;
                end

                NEXT_NUMBER: begin
                    // Add current number's sum to total running sum
                    running_sum <= running_sum + temp_sum;
                    // Reset temp sum for next number
                    temp_sum <= 8'b0;
                    // Reset char index for next number
                    current_char_index <= 3'b0;
                    // Move to next number
                    current_num_index <= current_num_index + 1;
                end

                DONE: begin
                    // Finalize result. 
                    // If we arrived here from NEXT_NUMBER, running_sum was updated in NEXT_NUMBER.
                    // If num_count was 0 (start), running_sum is 0.
                    result <= running_sum;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule