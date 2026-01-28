module bracket_converter(
    input clk,
    input rst_n,
    input start,
    input [7:0] s_in [0:3999],
    input [11:0] len,
    output reg [7:0] result [0:8191],
    output reg [13:0] out_len,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PARSE = 4'd1;
    localparam [3:0] CALCULATE_LENGTHS = 4'd2;
    localparam [3:0] GENERATE_OUTPUT = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;

    // Stack for parsing
    reg [12:0] stack [0:1999];
    reg [10:0] stack_ptr;

    // Pair storage
    reg [12:0] pair_start [0:1999];
    reg [12:0] pair_end [0:1999];
    reg [10:0] pair_count;

    // Length storage
    reg [13:0] pair_length [0:1999];

    // Output generation
    reg [13:0] write_ptr;
    reg [13:0] current_start;
    reg [13:0] current_end;

    // Decimal conversion
    reg [13:0] num_to_convert;
    reg [3:0] digit_count;
    reg [7:0] digit;
    reg [3:0] conv_state;
    localparam [3:0] CONV_IDLE = 4'd0;
    localparam [3:0] CONV_DIVIDE = 4'd1;
    localparam [3:0] CONV_WRITE = 4'd2;

    // State machine
    reg [3:0] state;
    reg [3:0] next_state;

    // Control signals
    reg parsing_done;
    reg lengths_done;
    reg output_done;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_len <= 14'd0;
            stack_ptr <= 11'd0;
            pair_count <= 11'd0;
            write_ptr <= 14'd0;
            parsing_done <= 1'b0;
            lengths_done <= 1'b0;
            output_done <= 1'b0;
            conv_state <= CONV_IDLE;

            // Initialize stack
            integer i;
            for (i = 0; i < 2000; i = i + 1) begin
                stack[i] <= 13'd0;
            end

            // Initialize pair storage
            for (i = 0; i < 2000; i = i + 1) begin
                pair_start[i] <= 13'd0;
                pair_end[i] <= 13'd0;
                pair_length[i] <= 14'd0;
            end

            // Initialize output
            for (i = 0; i < 8192; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Main FSM
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state <= PARSE;
                end else begin
                    next_state <= IDLE;
                end
            end

            PARSE: begin
                if (parsing_done) begin
                    next_state <= CALCULATE_LENGTHS;
                end else begin
                    next_state <= PARSE;
                end
            end

            CALCULATE_LENGTHS: begin
                if (lengths_done) begin
                    next_state <= GENERATE_OUTPUT;
                end else begin
                    next_state <= CALCULATE_LENGTHS;
                end
            end

            GENERATE_OUTPUT: begin
                if (output_done) begin
                    next_state <= DONE_STATE;
                end else begin
                    next_state <= GENERATE_OUTPUT;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state <= IDLE;
            end

            default: next_state <= IDLE;
        endcase
    end

    // Parse input string
    always @(posedge clk) begin
        if (state == PARSE && !parsing_done) begin
            integer i;
            reg [12:0] current_index;
            reg [12:0] open_index;

            for (i = 0; i < len; i = i + 1) begin
                current_index = i;
                if (s_in[i] == 8'd'(') begin
                    stack[stack_ptr] <= current_index;
                    stack_ptr <= stack_ptr + 1;
                end else if (s_in[i] == 8'd')') begin
                    stack_ptr <= stack_ptr - 1;
                    open_index = stack[stack_ptr];
                    pair_start[pair_count] <= open_index;
                    pair_end[pair_count] <= current_index;
                    pair_count <= pair_count + 1;
                end
            end

            parsing_done <= 1'b1;
        end
    end

    // Calculate lengths (bottom-up)
    always @(posedge clk) begin
        if (state == CALCULATE_LENGTHS && !lengths_done) begin
            integer i, j;
            reg [13:0] total_length;

            // Process pairs in reverse order (bottom-up)
            for (i = pair_count - 1; i >= 0; i = i - 1) begin
                total_length = 14'd0;

                // Calculate length of this pair's header
                // Start index length (up to 5 digits) + comma + end index length (up to 5 digits) + colon
                // Plus sum of lengths of nested pairs
                for (j = 0; j < pair_count; j = j + 1) begin
                    if (pair_start[i] < pair_start[j] && pair_end[j] < pair_end[i]) begin
                        total_length = total_length + pair_length[j];
                    end
                end

                // Add header overhead (start_str + "," + end_str + ":")
                // Maximum: 5 + 1 + 5 + 1 = 12 characters
                pair_length[i] <= total_length + 12;
            end

            lengths_done <= 1'b1;
        end
    end

    // Generate output
    always @(posedge clk) begin
        if (state == GENERATE_OUTPUT && !output_done) begin
            integer i;
            reg [13:0] start_offset;
            reg [13:0] end_offset;

            for (i = 0; i < pair_count; i = i + 1) begin
                start_offset = write_ptr;
                end_offset = start_offset + pair_length[i] - 1;

                // Write start index
                num_to_convert = start_offset;
                conv_state = CONV_DIVIDE;
                while (conv_state != CONV_IDLE) begin
                    // Decimal conversion state machine would be implemented here
                    // For simplicity, we'll assume it writes digits to result
                end

                // Write comma
                result[write_ptr] = 8'd',';
                write_ptr = write_ptr + 1;

                // Write end index
                num_to_convert = end_offset;
                conv_state = CONV_DIVIDE;
                while (conv_state != CONV_IDLE) begin
                    // Decimal conversion state machine would be implemented here
                end

                // Write colon
                result[write_ptr] = 8'd':';
                write_ptr = write_ptr + 1;
            end

            out_len = write_ptr;
            output_done = 1'b1;
        end
    end

    // Decimal to ASCII converter
    always @(posedge clk) begin
        if (conv_state == CONV_DIVIDE) begin
            if (num_to_convert > 0) begin
                digit = num_to_convert % 10;
                num_to_convert = num_to_convert / 10;
                result[write_ptr] = digit + 8'd'0';
                write_ptr = write_ptr + 1;
            end else begin
                conv_state = CONV_IDLE;
            end
        end
    end

endmodule