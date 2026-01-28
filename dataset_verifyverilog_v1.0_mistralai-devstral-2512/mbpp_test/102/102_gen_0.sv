module snake_to_camel(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:15],
    input wire [3:0] len,
    output reg [7:0] output_str [0:15],
    output reg done,
    output reg [3:0] result_len
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] CONVERT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] input_ptr;
    reg [3:0] output_ptr;
    reg [7:0] input_buffer [0:15];
    reg [7:0] output_buffer [0:15];
    reg capitalize_next;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd32;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            input_ptr <= 4'd0;
            output_ptr <= 4'd0;
            capitalize_next <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_len <= 4'd0;

            // Initialize input buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                input_buffer[i] <= 8'd0;
            end

            // Initialize output buffer and output_str
            for (i = 0; i < 16; i = i + 1) begin
                output_buffer[i] <= 8'd0;
                output_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load input string into buffer
                    if (input_ptr < len) begin
                        input_buffer[input_ptr] <= input_str[input_ptr];
                        input_ptr <= input_ptr + 4'd1;
                        next_state <= LOAD;
                    end else begin
                        input_ptr <= 4'd0;
                        output_ptr <= 4'd0;
                        capitalize_next <= 1'b0;
                        next_state <= CONVERT;
                    end
                end

                CONVERT: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (input_ptr < len) begin
                        // Process current character
                        if (input_buffer[input_ptr] == 8'h5F) begin
                            // Underscore found - set capitalize flag
                            capitalize_next <= 1'b1;
                            input_ptr <= input_ptr + 4'd1;
                        end else begin
                            // Regular character
                            reg [7:0] current_char;
                            current_char = input_buffer[input_ptr];

                            // Check if we need to capitalize
                            if (capitalize_next && 
                                ((current_char >= 8'h61 && current_char <= 8'h7A))) begin
                                // Convert lowercase to uppercase
                                current_char = current_char - 8'h20;
                                capitalize_next <= 1'b0;
                            end

                            // Store in output buffer
                            output_buffer[output_ptr] = current_char;
                            output_ptr <= output_ptr + 4'd1;
                            input_ptr <= input_ptr + 4'd1;
                        end

                        next_state <= CONVERT;
                    end else begin
                        // Finished processing
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result_len <= output_ptr;

                    // Copy output buffer to output_str
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        output_str[i] <= output_buffer[i];
                    end

                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule