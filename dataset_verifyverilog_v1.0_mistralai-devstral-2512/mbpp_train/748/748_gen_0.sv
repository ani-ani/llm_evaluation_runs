module capital_words_spaces (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] len,
    output reg [7:0] char_out,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] SCAN = 3'd2;
    localparam [2:0] INSERT_SPACE = 3'd3;
    localparam [2:0] OUTPUT_CHAR = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Input buffer (16x8-bit RAM)
    reg [7:0] input_buffer [0:15];
    reg [3:0] input_ptr;
    reg [3:0] input_len;

    // Output buffer (32x8-bit)
    reg [7:0] output_buffer [0:31];
    reg [4:0] output_ptr;
    reg [4:0] output_len;

    // FSM state
    reg [2:0] state, next_state;

    // Control signals
    reg [3:0] scan_ptr;
    reg [4:0] write_ptr;
    reg [7:0] prev_char;
    reg is_first_char;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Character detection
    wire is_lowercase = (char_in >= 8'd97 && char_in <= 8'd122);
    wire is_uppercase = (char_in >= 8'd65 && char_in <= 8'd90);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            input_ptr <= 4'd0;
            output_ptr <= 5'd0;
            scan_ptr <= 4'd0;
            write_ptr <= 5'd0;
            prev_char <= 8'd0;
            is_first_char <= 1'b1;
            cycle_count <= 8'd0;
            char_out <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;

            // Initialize input buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                input_buffer[i] <= 8'd0;
            end

            // Initialize output buffer
            for (i = 0; i < 32; i = i + 1) begin
                output_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= READ_INPUT;
                        input_ptr <= 4'd0;
                        input_len <= len;
                        cycle_count <= 8'd0;
                    end
                end

                READ_INPUT: begin
                    if (input_ptr < input_len) begin
                        input_buffer[input_ptr] <= char_in;
                        input_ptr <= input_ptr + 4'd1;
                    end else begin
                        next_state <= SCAN;
                        scan_ptr <= 4'd0;
                        write_ptr <= 5'd0;
                        prev_char <= 8'd0;
                        is_first_char <= 1'b1;
                    end
                end

                SCAN: begin
                    if (scan_ptr < input_len) begin
                        // Check if we need to insert space
                        if (!is_first_char && 
                            (input_buffer[scan_ptr] >= 8'd65 && input_buffer[scan_ptr] <= 8'd90) &&
                            (prev_char >= 8'd97 && prev_char <= 8'd122)) begin
                            next_state <= INSERT_SPACE;
                        end else begin
                            next_state <= OUTPUT_CHAR;
                        end
                        prev_char <= input_buffer[scan_ptr];
                        is_first_char <= 1'b0;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                INSERT_SPACE: begin
                    output_buffer[write_ptr] <= 8'd32; // Space character
                    write_ptr <= write_ptr + 5'd1;
                    next_state <= OUTPUT_CHAR;
                end

                OUTPUT_CHAR: begin
                    output_buffer[write_ptr] <= input_buffer[scan_ptr];
                    write_ptr <= write_ptr + 5'd1;
                    scan_ptr <= scan_ptr + 4'd1;
                    next_state <= SCAN;
                end

                DONE_STATE: begin
                    if (output_ptr < write_ptr) begin
                        char_out <= output_buffer[output_ptr];
                        valid <= 1'b1;
                        output_ptr <= output_ptr + 5'd1;
                    end else begin
                        done <= 1'b1;
                        valid <= 1'b0;
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase

            // Cycle counter for timeout
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else if (state != IDLE && state != DONE_STATE) begin
                next_state <= IDLE;
            end
        end
    end

endmodule