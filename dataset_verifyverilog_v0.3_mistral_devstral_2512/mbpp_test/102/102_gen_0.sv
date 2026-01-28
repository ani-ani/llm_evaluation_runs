module snake_to_camel(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:15],
    input wire [4:0] input_len,
    output reg [7:0] output_str [0:15],
    output reg [4:0] output_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CAPITALIZE = 3'd1;
    localparam [2:0] UNDERSCORE_WAIT = 3'd2;
    localparam [2:0] COPY_UPPER = 3'd3;
    localparam [2:0] COPY_LOWER = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [4:0] input_index;
    reg [4:0] output_index;
    reg underscore_flag;

    // ASCII constants
    localparam [7:0] UNDERSCORE = 8'd95;
    localparam [7:0] LOWER_A = 8'd97;
    localparam [7:0] LOWER_Z = 8'd122;
    localparam [7:0] UPPER_A = 8'd65;
    localparam [7:0] UPPER_Z = 8'd90;
    localparam [7:0] CASE_DIFF = 8'd32;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_index <= 5'd0;
            output_index <= 5'd0;
            underscore_flag <= 1'b0;
            done <= 1'b0;
            output_len <= 5'd0;
            // Initialize output array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                output_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CAPITALIZE;
                end
            end

            CAPITALIZE: begin
                if (input_index == input_len) begin
                    next_state = DONE_STATE;
                end else if (input_str[input_index] == UNDERSCORE) begin
                    next_state = UNDERSCORE_WAIT;
                end else begin
                    next_state = COPY_LOWER;
                end
            end

            UNDERSCORE_WAIT: begin
                if (input_index == input_len) begin
                    next_state = DONE_STATE;
                end else if (input_str[input_index] != UNDERSCORE) begin
                    next_state = COPY_UPPER;
                end
            end

            COPY_UPPER: begin
                if (input_index == input_len) begin
                    next_state = DONE_STATE;
                end else if (input_str[input_index] == UNDERSCORE) begin
                    next_state = UNDERSCORE_WAIT;
                end else begin
                    next_state = COPY_LOWER;
                end
            end

            COPY_LOWER: begin
                if (input_index == input_len) begin
                    next_state = DONE_STATE;
                end else if (input_str[input_index] == UNDERSCORE) begin
                    next_state = UNDERSCORE_WAIT;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state register
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                CAPITALIZE: begin
                    if (input_index < input_len) begin
                        // Capitalize first character
                        if (input_str[input_index] >= LOWER_A && input_str[input_index] <= LOWER_Z) begin
                            output_str[output_index] <= input_str[input_index] - CASE_DIFF;
                        end else begin
                            output_str[output_index] <= input_str[input_index];
                        end
                        input_index <= input_index + 1'b1;
                        output_index <= output_index + 1'b1;
                    end
                end

                UNDERSCORE_WAIT: begin
                    if (input_str[input_index] != UNDERSCORE) begin
                        input_index <= input_index + 1'b1;
                    end else begin
                        input_index <= input_index + 1'b1;
                    end
                end

                COPY_UPPER: begin
                    if (input_index < input_len) begin
                        // Capitalize character after underscore
                        if (input_str[input_index] >= LOWER_A && input_str[input_index] <= LOWER_Z) begin
                            output_str[output_index] <= input_str[input_index] - CASE_DIFF;
                        end else begin
                            output_str[output_index] <= input_str[input_index];
                        end
                        input_index <= input_index + 1'b1;
                        output_index <= output_index + 1'b1;
                    end
                end

                COPY_LOWER: begin
                    if (input_index < input_len) begin
                        // Copy character as-is
                        output_str[output_index] <= input_str[input_index];
                        input_index <= input_index + 1'b1;
                        output_index <= output_index + 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    output_len <= output_index;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule