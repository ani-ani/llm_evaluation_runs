module NenScriptInterpreter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input line_end,
    output reg [7:0] char_out,
    output reg char_out_valid,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PARSE_CMD = 4'd1;
    localparam [3:0] PARSE_VAR = 4'd2;
    localparam [3:0] PARSE_PRINT = 4'd3;
    localparam [3:0] PARSE_END = 4'd4;
    localparam [3:0] EVAL_EXPR = 4'd5;
    localparam [3:0] EVAL_TEMPLATE = 4'd6;
    localparam [3:0] OUTPUT = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state, next_state;

    // Variable storage (16 variables, max 10 char names, 16 char values)
    reg [7:0] var_names [0:15][0:9];
    reg [7:0] var_values [0:15][0:15];
    reg [3:0] var_count;

    // Input buffer (128 bytes)
    reg [7:0] input_buffer [0:127];
    reg [6:0] input_ptr, input_end;

    // Output buffer (128 bytes)
    reg [7:0] output_buffer [0:127];
    reg [6:0] output_ptr, output_end;

    // Expression evaluation stack (depth 4)
    reg [7:0] eval_stack [0:3][0:15];
    reg [1:0] eval_stack_ptr;

    // Current token and position
    reg [7:0] current_token [0:15];
    reg [3:0] token_len;
    reg [6:0] token_pos;

    // Template evaluation state
    reg in_template;
    reg [6:0] template_ptr;

    // Control signals
    reg [6:0] i;
    reg [3:0] j;
    reg found;
    reg match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            var_count <= 4'd0;
            input_ptr <= 7'd0;
            input_end <= 7'd0;
            output_ptr <= 7'd0;
            output_end <= 7'd0;
            eval_stack_ptr <= 2'd0;
            token_len <= 4'd0;
            token_pos <= 7'd0;
            in_template <= 1'b0;
            template_ptr <= 7'd0;
            char_out <= 8'd0;
            char_out_valid <= 1'b0;
            done <= 1'b0;

            // Initialize variable storage
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 10; j = j + 1) begin
                    var_names[i][j] <= 8'd0;
                end
                for (j = 0; j < 16; j = j + 1) begin
                    var_values[i][j] <= 8'd0;
                end
            end

            // Initialize input buffer
            for (i = 0; i < 128; i = i + 1) begin
                input_buffer[i] <= 8'd0;
            end

            // Initialize output buffer
            for (i = 0; i < 128; i = i + 1) begin
                output_buffer[i] <= 8'd0;
            end

            // Initialize evaluation stack
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    eval_stack[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            char_out_valid <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        input_ptr <= 7'd0;
                        input_end <= 7'd0;
                        next_state <= PARSE_CMD;
                    end
                end

                PARSE_CMD: begin
                    if (char_valid) begin
                        input_buffer[input_ptr] <= char_in;
                        input_ptr <= input_ptr + 7'd1;
                        if (line_end) begin
                            input_end <= input_ptr;
                            next_state <= PARSE_CMD;
                        end
                    end else if (input_end > 7'd0) begin
                        // Parse command
                        if (input_buffer[7'd0] == 8'"v" && input_buffer[7'd1] == 8'"a" && input_buffer[7'd2] == 8'"r") begin
                            next_state <= PARSE_VAR;
                        end else if (input_buffer[7'd0] == 8'"p" && input_buffer[7'd1] == 8'"r" && input_buffer[7'd2] == 8'"i" && input_buffer[7'd3] == 8'"n" && input_buffer[7'd4] == 8'"t") begin
                            next_state <= PARSE_PRINT;
                        end else if (input_buffer[7'd0] == 8'"e" && input_buffer[7'd1] == 8'"n" && input_buffer[7'd2] == 8'"d" && input_buffer[7'd3] == 8'"\.") begin
                            next_state <= PARSE_END;
                        end else begin
                            next_state <= IDLE;
                        end
                    end
                end

                PARSE_VAR: begin
                    // Parse var <name> = <value>;
                    token_pos <= 7'd4; // Skip "var "
                    token_len <= 4'd0;

                    // Extract variable name
                    while (input_buffer[token_pos] != 8'" " && input_buffer[token_pos] != 8'"=") begin
                        current_token[token_len] <= input_buffer[token_pos];
                        token_len <= token_len + 4'd1;
                        token_pos <= token_pos + 7'd1;
                    end

                    // Skip to value
                    token_pos <= token_pos + 7'd2; // Skip "= "

                    // Evaluate expression
                    next_state <= EVAL_EXPR;
                end

                PARSE_PRINT: begin
                    // Parse print <expr>;
                    token_pos <= 7'd6; // Skip "print "

                    // Evaluate expression
                    next_state <= EVAL_EXPR;
                end

                PARSE_END: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                EVAL_EXPR: begin
                    if (input_buffer[token_pos] == 8'"`") begin
                        // Template literal
                        in_template <= 1'b1;
                        template_ptr <= token_pos + 7'd1;
                        next_state <= EVAL_TEMPLATE;
                    end else begin
                        // Variable reference
                        token_len <= 4'd0;
                        while (input_buffer[token_pos] != 8'" " && input_buffer[token_pos] != 8'"\;") begin
                            current_token[token_len] <= input_buffer[token_pos];
                            token_len <= token_len + 4'd1;
                            token_pos <= token_pos + 7'd1;
                        end

                        // Lookup variable
                        found <= 1'b0;
                        for (i = 0; i < var_count; i = i + 1) begin
                            match <= 1'b1;
                            for (j = 0; j < token_len; j = j + 1) begin
                                if (var_names[i][j] != current_token[j]) begin
                                    match <= 1'b0;
                                end
                            end
                            if (match) begin
                                found <= 1'b1;
                                // Copy value to output buffer
                                output_end <= 7'd0;
                                for (j = 0; j < 16; j = j + 1) begin
                                    if (var_values[i][j] != 8'd0) begin
                                        output_buffer[output_end] <= var_values[i][j];
                                        output_end <= output_end + 7'd1;
                                    end
                                end
                                break;
                            end
                        end

                        if (found) begin
                            if (state == PARSE_VAR) begin
                                // Store in variable table
                                for (i = 0; i < token_len; i = i + 1) begin
                                    var_names[var_count][i] <= current_token[i];
                                end
                                for (i = 0; i < output_end; i = i + 1) begin
                                    var_values[var_count][i] <= output_buffer[i];
                                end
                                var_count <= var_count + 4'd1;
                                next_state <= IDLE;
                            end else if (state == PARSE_PRINT) begin
                                // Output the value
                                output_ptr <= 7'd0;
                                next_state <= OUTPUT;
                            end
                        end else begin
                            next_state <= IDLE;
                        end
                    end
                end

                EVAL_TEMPLATE: begin
                    output_end <= 7'd0;
                    while (template_ptr < input_end) begin
                        if (input_buffer[template_ptr] == 8'"`") begin
                            template_ptr <= template_ptr + 7'd1;
                            break;
                        end else if (input_buffer[template_ptr] == 8'"$" && input_buffer[template_ptr + 7'd1] == 8'"{") begin
                            // Embedded expression
                            template_ptr <= template_ptr + 7'd2;
                            token_pos <= template_ptr;
                            next_state <= EVAL_EXPR;
                            break;
                        end else begin
                            // Static string
                            output_buffer[output_end] <= input_buffer[template_ptr];
                            output_end <= output_end + 7'd1;
                            template_ptr <= template_ptr + 7'd1;
                        end
                    end

                    if (template_ptr >= input_end) begin
                        if (state == PARSE_VAR) begin
                            // Store in variable table
                            for (i = 0; i < token_len; i = i + 1) begin
                                var_names[var_count][i] <= current_token[i];
                            end
                            for (i = 0; i < output_end; i = i + 1) begin
                                var_values[var_count][i] <= output_buffer[i];
                            end
                            var_count <= var_count + 4'd1;
                            next_state <= IDLE;
                        end else if (state == PARSE_PRINT) begin
                            // Output the value
                            output_ptr <= 7'd0;
                            next_state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    if (output_ptr < output_end) begin
                        char_out <= output_buffer[output_ptr];
                        char_out_valid <= 1'b1;
                        output_ptr <= output_ptr + 7'd1;
                    end else begin
                        char_out <= 8'd10; // Newline
                        char_out_valid <= 1'b1;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule