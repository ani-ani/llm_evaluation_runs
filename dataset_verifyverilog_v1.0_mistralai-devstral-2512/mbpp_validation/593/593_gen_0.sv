module IPv4LeadingZeroRemover(
    input clk,
    input rst_n,
    input start,
    input [63:0] ip_in,
    input [3:0] len_in,
    output reg [63:0] ip_out,
    output reg [3:0] len_out,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_OCTET = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] ERROR = 3'd3;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] octet_count;
    reg [3:0] digit_count;
    reg [3:0] input_index;
    reg [3:0] output_index;
    reg [7:0] current_octet [0:3];
    reg [7:0] current_digit;
    reg [7:0] prev_char;
    reg leading_zero;
    reg octet_start;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 8'd255;

    // FSM state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            octet_count <= 4'd0;
            digit_count <= 4'd0;
            input_index <= 4'd0;
            output_index <= 4'd0;
            leading_zero <= 1'b0;
            octet_start <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            ip_out <= 64'd0;
            len_out <= 4'd0;
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
                    next_state = PARSE_OCTET;
                    octet_count = 4'd0;
                    digit_count = 4'd0;
                    input_index = 4'd0;
                    output_index = 4'd0;
                    leading_zero = 1'b0;
                    octet_start = 1'b1;
                    cycle_count = 8'd0;
                    done = 1'b0;
                    error = 1'b0;
                end
            end

            PARSE_OCTET: begin
                if (input_index >= len_in) begin
                    if (octet_count != 4'd4) begin
                        next_state = ERROR;
                        error = 1'b1;
                    end else begin
                        next_state = OUTPUT;
                    end
                end else begin
                    current_digit = ip_in[(input_index * 8) +: 8];
                    if (current_digit == 8'd46) begin // Dot
                        if (digit_count == 4'd0 || digit_count > 4'd3) begin
                            next_state = ERROR;
                            error = 1'b1;
                        end else begin
                            octet_count = octet_count + 4'd1;
                            digit_count = 4'd0;
                            leading_zero = 1'b0;
                            octet_start = 1'b1;
                            input_index = input_index + 4'd1;
                        end
                    end else if (current_digit >= 8'd48 && current_digit <= 8'd57) begin // Digit
                        if (digit_count == 4'd0 && current_digit == 8'd48) begin
                            leading_zero = 1'b1;
                        end else begin
                            leading_zero = 1'b0;
                        end
                        digit_count = digit_count + 4'd1;
                        input_index = input_index + 4'd1;
                        octet_start = 1'b0;
                    end else begin
                        next_state = ERROR;
                        error = 1'b1;
                    end
                end
            end

            OUTPUT: begin
                if (output_index >= 4'd15) begin
                    next_state = IDLE;
                    done = 1'b1;
                end else begin
                    if (octet_count < 4'd4) begin
                        if (leading_zero && !octet_start && digit_count > 4'd1) begin
                            // Skip leading zero
                            input_index = input_index + 4'd1;
                        end else begin
                            ip_out[(output_index * 8) +: 8] = ip_in[(input_index * 8) +: 8];
                            output_index = output_index + 4'd1;
                            input_index = input_index + 4'd1;
                        end
                    end else begin
                        next_state = IDLE;
                        done = 1'b1;
                    end
                end
            end

            ERROR: begin
                next_state = IDLE;
                error = 1'b1;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE) begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                error <= 1'b1;
            end
        end
    end

    // Output length calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            len_out <= 4'd0;
        end else if (done) begin
            len_out <= output_index;
        end
    end

endmodule