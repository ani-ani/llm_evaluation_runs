module move_num (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    // Parameters
    parameter INPUT_WIDTH = 16;
    parameter CHAR_WIDTH = 8;
    parameter NULL_CHAR = 8'h00;

    // ASCII Digit definitions
    localparam DIGIT_MIN = 8'h30;
    localparam DIGIT_MAX = 8'h39;

    // State encoding
    localparam IDLE = 3'b000;
    localparam INPUT_COLLECT = 3'b001;
    localparam OUTPUT_NON_DIGITS = 3'b010;
    localparam OUTPUT_DIGITS = 3'b011;
    localparam DONE = 3'b100;

    // Internal Registers and Wires
    reg [2:0] current_state, next_state;
    reg [3:0] input_count;
    reg [3:0] output_count;
    
    // Buffers: 16 entries each
    reg [CHAR_WIDTH-1:0] buffer_non_digit [0:INPUT_WIDTH-1];
    reg [CHAR_WIDTH-1:0] buffer_digit [0:INPUT_WIDTH-1];
    
    // Counters for how many items are actually in each buffer
    reg [3:0] count_non_digit;
    reg [3:0] count_digit;
    
    // Pointer to current index in specific buffer during output
    reg [3:0] current_read_index;

    // Logic for detecting digits
    wire is_digit;
    assign is_digit = (char_in >= DIGIT_MIN && char_in <= DIGIT_MAX);

    // State Register
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
                    next_state = INPUT_COLLECT;
                else
                    next_state = IDLE;
            end
            INPUT_COLLECT: begin
                if (input_count == INPUT_WIDTH && valid_in)
                    next_state = OUTPUT_NON_DIGITS;
                else
                    next_state = INPUT_COLLECT;
            end
            OUTPUT_NON_DIGITS: begin
                if (output_count == count_non_digit)
                    next_state = OUTPUT_DIGITS;
                else
                    next_state = OUTPUT_NON_DIGITS;
            end
            OUTPUT_DIGITS: begin
                if (output_count == count_digit)
                    next_state = DONE;
                else
                    next_state = OUTPUT_DIGITS;
            end
            DONE: begin
                if (start) // Ready for next sequence if start resets or re-triggers logic (assuming valid_in handled after start)
                    next_state = INPUT_COLLECT;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic (Moore-style logic implemented in sequential block for stability)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_out <= NULL_CHAR;
            valid_out <= 1'b0;
            done <= 1'b0;
            input_count <= 4'd0;
            output_count <= 4'd0;
            count_non_digit <= 4'd0;
            count_digit <= 4'd0;
            current_read_index <= 4'd0;
            // Initialize buffers (optional but good practice)
            // Verilog doesn't support loops for init in synthesis easily for arrays, 
            // relying on reset logic downstream or assigning 0 explicitly if needed.
            // For this design, we track valid counts, so uninitialized data is ignored.
        end else begin
            // Default assignments
            valid_out <= 1'b0;
            done <= 1'b0;
            char_out <= NULL_CHAR;

            case (current_state)
                IDLE: begin
                    // Wait for start
                    input_count <= 4'd0;
                    output_count <= 4'd0;
                    count_non_digit <= 4'd0;
                    count_digit <= 4'd0;
                    current_read_index <= 4'd0;
                end

                INPUT_COLLECT: begin
                    if (valid_in) begin
                        input_count <= input_count + 1;
                        if (is_digit) begin
                            buffer_digit[count_digit] <= char_in;
                            count_digit <= count_digit + 1;
                        end else begin
                            buffer_non_digit[count_non_digit] <= char_in;
                            count_non_digit <= count_non_digit + 1;
                        end
                    end
                end

                OUTPUT_NON_DIGITS: begin
                    if (output_count < count_non_digit) begin
                        char_out <= buffer_non_digit[output_count];
                        valid_out <= 1'b1;
                        output_count <= output_count + 1;
                    end else begin
                        // Finished non-digits, prepare for digits
                        output_count <= 4'd0;
                        // State transition handled in next_state logic
                    end
                end

                OUTPUT_DIGITS: begin
                    if (output_count < count_digit) begin
                        char_out <= buffer_digit[output_count];
                        valid_out <= 1'b1;
                        output_count <= output_count + 1;
                    end else begin
                        // Finished digits
                        // State transition handled in next_state logic
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Output valid_out might stay low here, or could pulse 0
                end
            endcase
        end
    end

endmodule