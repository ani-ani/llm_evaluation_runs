module reverse_vowels (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire valid_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COLLECT_VOWELS = 2'b01;
    localparam OUTPUT_CHARS = 2'b10;

    // Internal Registers
    reg [1:0] current_state, next_state;
    reg [7:0] char_buffer[0:7]; // Buffer to store all 8 characters
    reg [7:0] vowel_buffer[0:7]; // Buffer to store extracted vowels
    reg [2:0] input_ptr; // Pointer for filling buffers (0-7)
    reg [3:0] vowel_count; // Count of vowels found
    reg [2:0] output_ptr; // Pointer for output phase (0-7)
    reg [3:0] cycle_count; // Counts cycles in OUTPUT state (0-15)

    // Vowel detection helper
    wire is_vowel;
    assign is_vowel = (
        (char_in == 8'h61) || (char_in == 8'h65) || (char_in == 8'h69) || (char_in == 8'h6F) || (char_in == 8'h75) ||
        (char_in == 8'h41) || (char_in == 8'h45) || (char_in == 8'h49) || (char_in == 8'h4F) || (char_in == 8'h55)
    );

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = COLLECT_VOWELS;
                else
                    next_state = IDLE;
            end
            COLLECT_VOWELS: begin
                // Wait until we have processed 8 valid characters
                if (valid_in && input_ptr == 3'd7)
                    next_state = OUTPUT_CHARS;
                else
                    next_state = COLLECT_VOWELS;
            end
            OUTPUT_CHARS: begin
                // Stay for 8 cycles
                if (output_cycle_counter == 3'd7) next_state = IDLE;
                else next_state = OUTPUT_CHARS;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            char_out <= 8'h00;
            valid_out <= 1'b0;
            done <= 1'b0;
            input_ptr <= 3'd0;
            vowel_count <= 4'd0;
            output_ptr <= 3'd0;
            cycle_count <= 4'd0;
            vowels_outputted <= 4'd0;
            output_cycle_counter <= 3'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    input_ptr <= 3'd0;
                    vowel_count <= 4'd0;
                    output_ptr <= 3'd0;
                    cycle_count <= 4'd0;
                    vowels_outputted <= 4'd0;
                end

                COLLECT_VOWELS: begin
                    if (valid_in) begin
                        // Store in char buffer
                        char_buffer[input_ptr] <= char_in;
                        
                        // Check for vowel
                        if (is_vowel) begin
                            vowel_buffer[vowel_count] <= char_in;
                            vowel_count <= vowel_count + 1;
                            valid_out <= 1'b0; // Vowels are suppressed during collect
                        end else begin
                            // Non-vowel: pass through
                            char_out <= char_in;
                            valid_out <= 1'b1;
                        end
                        done <= 1'b0;
                        input_ptr <= input_ptr + 1;
                    end else begin
                        valid_out <= 1'b0;
                    end
                    // Increment cycle counter to track total elapsed time (16 cycles total)
                    if (valid_in) cycle_count <= cycle_count + 1;
                end

                OUTPUT_CHARS: begin
                    // We need to output the vowels in reverse order.
                    // We output one per cycle.
                    if (vowels_outputted < vowel_count) begin
                        // Output vowel from reverse index
                        char_out <= vowel_buffer[vowel_count - 1 - vowels_outputted];
                        valid_out <= 1'b1;
                        vowels_outputted <= vowels_outputted + 1;
                    end else begin
                        // No more vowels to output, or we are just padding to 8 cycles
                        valid_out <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Logic to keep `vowels_outputted` counting up during OUTPUT to handle the "Next 8 cycles" duration
    // even if we run out of vowels.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_cycle_counter <= 3'd0;
        end else begin
            if (current_state == IDLE) output_cycle_counter <= 3'd0;
            else if (current_state == OUTPUT_CHARS) output_cycle_counter <= output_cycle_counter + 1;
        end
    end

    // Final adjustments for `done` signal:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (current_state == OUTPUT_CHARS && output_cycle_counter == 3'd7) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule