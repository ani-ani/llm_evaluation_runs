module move_digits_to_end(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_string [0:15],
    input wire [3:0] valid_length,
    output reg [7:0] output_string [0:15],
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FIRST_PASS = 4'd1;
    localparam [3:0] SECOND_PASS = 4'd2;
    localparam [3:0] PADDING = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;

    // Internal registers
    reg [3:0] state;
    reg [3:0] char_index;
    reg [3:0] non_digit_count;
    reg [3:0] digit_count;
    reg [7:0] digit_buffer [0:15];
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Digit detection
    function is_digit;
        input [7:0] char;
        begin
            is_digit = (char >= 8'd48 && char <= 8'd57);
        end
    endfunction

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_index <= 4'd0;
            non_digit_count <= 4'd0;
            digit_count <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize output string and digit buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                output_string[i] <= 8'd0;
                digit_buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= FIRST_PASS;
                        char_index <= 4'd0;
                        non_digit_count <= 4'd0;
                        digit_count <= 4'd0;
                    end
                end

                FIRST_PASS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_index < valid_length) begin
                        if (is_digit(input_string[char_index])) begin
                            digit_buffer[digit_count] <= input_string[char_index];
                            digit_count <= digit_count + 4'd1;
                        end else begin
                            output_string[non_digit_count] <= input_string[char_index];
                            non_digit_count <= non_digit_count + 4'd1;
                        end
                        char_index <= char_index + 4'd1;
                    end else begin
                        char_index <= 4'd0;
                        state <= SECOND_PASS;
                    end
                end

                SECOND_PASS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_index < digit_count) begin
                        output_string[non_digit_count + char_index] <= digit_buffer[char_index];
                        char_index <= char_index + 4'd1;
                    end else begin
                        char_index <= 4'd0;
                        state <= PADDING;
                    end
                end

                PADDING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_index < 16) begin
                        if (char_index >= non_digit_count + digit_count) begin
                            output_string[char_index] <= 8'd32; // Space character
                        end
                        char_index <= char_index + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule