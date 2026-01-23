module nenscript_evaluator(
    input clk,
    input rst_n,
    input start,
    input cmd_type,
    input [20479:0] line_buffer,
    input [7:0] line_length,
    output reg [255:0] result,
    output reg [7:0] result_length,
    output reg done,
    output reg error
);

    parameter MAX_VARS = 8;
    parameter MAX_NAME_LEN = 10;
    parameter MAX_VAL_LEN = 16;
    parameter MAX_TEMPLATE_DEPTH = 3;

    // Variable Storage (Packed)
    reg [79:0] var_names [0:MAX_VARS-1];
    reg [127:0] var_values [0:MAX_VARS-1];
    reg [3:0] var_name_len [0:MAX_VARS-1];
    reg [4:0] var_val_len [0:MAX_VARS-1];
    reg [2:0] var_count;

    // States
    localparam IDLE = 0, PARSE_DECL = 1, PARSE_PRINT = 2, EVAL_EXPR = 3, UPDATE_VAR = 4, FINISHED = 5, ERROR_STATE = 6;
    reg [3:0] state;

    // Eval Sub-States (used as eval_step)
    localparam E_INIT = 0, E_CHECK = 1, E_LIT = 2, E_VAR = 3, E_TMPL = 4, E_BRACE = 5, E_RESUME = 6, E_DONE = 7;
    
    // Buffers & Indices
    reg [79:0] work_buffer;
    reg [6:0] parse_idx;
    reg [6:0] expr_start, expr_len;
    reg [6:0] name_start, name_len;
    
    // Evaluation Context
    reg [255:0] current_expr_str;
    reg [7:0] current_expr_len;
    reg [7:0] current_pos;
    reg [255:0] eval_result_str;
    reg [7:0] eval_result_len;
    
    // Stack
    reg [255:0] stack_res_str [0:MAX_TEMPLATE_DEPTH-1];
    reg [7:0] stack_res_len [0:MAX_TEMPLATE_DEPTH-1];
    reg [255:0] stack_expr_str [0:MAX_TEMPLATE_DEPTH-1];
    reg [7:0] stack_expr_len [0:MAX_TEMPLATE_DEPTH-1];
    reg [7:0] stack_expr_pos [0:MAX_TEMPLATE_DEPTH-1];
    reg [2:0] sp;
    
    // Temp Registers
    reg [79:0] temp_name_str;
    reg [7:0] temp_name_len_reg;
    reg [255:0] temp_val_str;
    reg [7:0] temp_val_len;
    reg [7:0] scan_idx;
    reg [3:0] brace_depth;
    reg in_quote;
    reg in_backtick;
    reg [2:0] eval_step;
    reg [2:0] call_return_state;
    reg found; // Used for scanning loops
    
    // Lookup Helpers
    reg [2:0] lookup_idx;
    reg lookup_found;
    reg [7:0] lookup_val_len;
    reg [255:0] lookup_val_str;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            var_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    if (start) begin
                        // Copy Line 0 (first 80 bytes) to work_buffer
                        for (i=0; i<80; i=i+1) begin
                            if (i < line_length) work_buffer[i*8 +: 8] <= line_buffer[i*8 +: 8];
                        end
                        parse_idx <= 0;
                        expr_start <= 0;
                        expr_len <= 0;
                        name_len <= 0;
                        if (cmd_type == 0) state <= PARSE_DECL;
                        else state <= PARSE_PRINT;
                    end
                end

                PARSE_DECL: begin
                    // Parse: var <name> = <expr> ;
                    // Find '=' and ';'
                    for (i=0; i<80; i=i+1) begin
                        if (work_buffer[i*8 +: 8] == 8'h3D && expr_start == 0) begin // '='
                            expr_start <= i + 1;
                            name_len <= i - 4; // "var " is 4 chars
                            // Copy name
                            for (j=0; j<10; j=j+1) begin
                                if (4+j < i) temp_name_str[j*8 +: 8] <= work_buffer[(4+j)*8 +: 8];
                            end
                        end
                        if (work_buffer[i*8 +: 8] == 8'h3B && expr_len == 0 && expr_start > 0) begin // ';'
                            expr_len <= i - expr_start;
                        end
                    end
                    
                    if (expr_len > 0 && expr_len < 33) begin
                        for (i=0; i<32; i=i+1) begin
                            if (i < expr_len) current_expr_str[i*8 +: 8] <= work_buffer[(expr_start + i)*8 +: 8];
                        end
                        current_expr_len <= expr_len;
                        eval_result_str <= 0;
                        eval_result_len <= 0;
                        current_pos <= 0;
                        sp <= 0;
                        eval_step <= E_INIT;
                        call_return_state <= 0;
                        state <= EVAL_EXPR;
                    end else begin
                        state <= ERROR_STATE;
                    end
                end

                PARSE_PRINT: begin
                    // Parse: print <expr> ;
                    for (i=0; i<80; i=i+1) begin
                        if (work_buffer[i*8 +: 8] == 8'h3B && expr_len == 0) begin // ';'
                            expr_len <= i - 6;
                            expr_start <= 6;
                        end
                    end
                    if (expr_len > 0 && expr_len < 33) begin
                        for (i=0; i<32; i=i+1) begin
                            if (i < expr_len) current_expr_str[i*8 +: 8] <= work_buffer[(6 + i)*8 +: 8];
                        end
                        current_expr_len <= expr_len;
                        eval_result_str <= 0;
                        eval_result_len <= 0;
                        current_pos <= 0;
                        sp <= 0;
                        eval_step <= E_INIT;
                        call_return_state <= 1;
                        state <= EVAL_EXPR;
                    end else begin
                        state <= ERROR_STATE;
                    end
                end

                EVAL_EXPR: begin
                    case (eval_step)
                        E_INIT: begin
                            current_pos <= 0;
                            eval_result_str <= 0;
                            eval_result_len <= 0;
                            sp <= 0;
                            eval_step <= E_CHECK;
                        end

                        E_CHECK: begin
                            if (current_pos >= current_expr_len) begin
                                if (sp > 0) eval_step <= E_RESUME;
                                else eval_step <= E_DONE;
                            end else begin
                                // Check char type
                                temp_val_len <= current_expr_str[current_pos*8 +: 8]; // Store char
                                if (current_expr_str[current_pos*8 +: 8] == 8'h22) // "
                                    eval_step <= E_LIT;
                                else if ((current_expr_str[current_pos*8 +: 8] >= 8'h61 && current_expr_str[current_pos*8 +: 8] <= 8'h7A) || current_expr_str[current_pos*8 +: 8] == 8'h5F) // a-z_
                                    eval_step <= E_VAR;
                                else if (current_expr_str[current_pos*8 +: 8] == 8'h60) // `
                                    eval_step <= E_TMPL;
                                else begin
                                    current_pos <= current_pos + 1;
                                end
                            end
                        end

                        E_LIT: begin
                            // String Literal "..."
                            if (scan_idx == 0) begin
                                // Extract Phase
                                temp_val_len <= 0; // Length found
                                found <= 0;
                                // Unrolled scan for closing quote
                                for (i=1; i<32; i=i+1) begin
                                    if (!found && current_pos + i < current_expr_len) begin
                                        if (current_expr_str[(current_pos + i)*8 +: 8] == 8'h22) begin
                                            found <= 1;
                                            temp_val_len <= i - 1;
                                            // Extract to temp_val_str
                                            for (int k=0; k<32; k=k+1) begin
                                                if (k < (i-1)) temp_val_str[k*8 +: 8] <= current_expr_str[(current_pos + 1 + k)*8 +: 8];
                                            end
                                            temp_name_len_reg <= current_pos + i + 1; // Store next pos
                                        end
                                    end
                                end
                                scan_idx <= 1;
                            end else begin
                                // Append Phase
                                if (temp_val_len > 0) begin
                                    eval_result_str <= eval_result_str | (temp_val_str >> (eval_result_len * 8));
                                    eval_result_len <= eval_result_len + temp_val_len;
                                    current_pos <= temp_name_len_reg;
                                end else begin
                                    state <= ERROR_STATE; // No closing quote
                                end
                                scan_idx <= 0;
                                eval_step <= E_CHECK;
                            end
                        end

                        E_VAR: begin
                            // Variable Reference
                            // Scan for length, Lookup, Append
                            if (scan_idx == 0) begin
                                // Start Length Scan
                                scan_idx <= 1;
                                temp_name_len_reg <= 1; // Assume min length
                            end else if (scan_idx < 10) begin
                                // Continue Length Scan
                                // Check char at current_pos + scan_idx
                                // If valid name char, continue. Else stop.
                                if ( (current_expr_str[(current_pos + scan_idx)*8 +: 8] >= 8'h61 && current_expr_str[(current_pos + scan_idx)*8 +: 8] <= 8'h7A) || current_expr_str[(current_pos + scan_idx)*8 +: 8] == 8'h5F ) begin
                                    scan_idx <= scan_idx + 1;
                                    temp_name_len_reg <= scan_idx + 1;
                                end else begin
                                    scan_idx <= 254; // Go to Lookup
                                end
                            end else if (scan_idx == 10 || (scan_idx < 254 && scan_idx >= 1)) begin
                                // Reached max or end of valid chars
                                scan_idx <= 254;
                            end else if (scan_idx == 254) begin
                                // Lookup Phase
                                // Extract Name
                                temp_val_str <= 0;
                                for (i=0; i<10; i=i+1) begin
                                    if (i < temp_name_len_reg) temp_val_str[i*8 +: 8] <= current_expr_str[(current_pos + i)*8 +: 8];
                                end
                                // Perform Lookup
                                lookup_found <= 0;
                                lookup_val_len <= 0;
                                lookup_val_str <= 0;
                                for (i=0; i<MAX_VARS; i=i+1) begin
                                    if (var_name_len[i] == temp_name_len_reg && !lookup_found) begin
                                        if (var_names[i] == temp_val_str[79:0]) begin
                                            lookup_found <= 1;
                                            lookup_val_len <= var_val_len[i];
                                            lookup_val_str[255:128] <= var_values[i];
                                        end
                                    end
                                end
                                scan_idx <= 255;
                            end else if (scan_idx == 255) begin
                                // Append Phase
                                if (lookup_found) begin
                                    eval_result_str <= eval_result_str | (lookup_val_str >> (eval_result_len * 8));
                                    eval_result_len <= eval_result_len + lookup_val_len;
                                    current_pos <= current_pos + temp_name_len_reg;
                                    scan_idx <= 0;
                                    eval_step <= E_CHECK;
                                end else begin
                                    state <= ERROR_STATE;
                                end
                            end
                        end

                        E_TMPL: begin
                            // Template Literal `...`
                            if (scan_idx == 0) begin
                                // Skip backtick
                                current_pos <= current_pos + 1;
                                scan_idx <= 1;
                            end else begin
                                // Scan Content
                                if (current_pos >= current_expr_len) begin
                                    state <= ERROR_STATE; // Missing closing backtick
                                end else begin
                                    temp_val_len <= current_expr_str[current_pos*8 +: 8];
                                    if (current_expr_str[current_pos*8 +: 8] == 8'h24 && current_pos + 1 < current_expr_len && current_expr_str[(current_pos+1)*8 +: 8] == 8'h7B) begin // ${\n                                        current_pos <= current_pos + 2; // Skip ${\n                                        eval_step <= E_BRACE;
                                        scan_idx <= 0;
                                    end else if (current_expr_str[current_pos*8 +: 8] == 8'h60) begin // `
                                        current_pos <= current_pos + 1;
                                        if (sp > 0) eval_step <= E_RESUME;
                                        else eval_step <= E_DONE;
                                    end else begin
                                        // Append literal char
                                        temp_val_str <= 0;
                                        temp_val_str[255:248] <= temp_val_len;
                                        eval_result_str <= eval_result_str | (temp_val_str >> (eval_result_len * 8));
                                        eval_result_len <= eval_result_len + 1;
                                        current_pos <= current_pos + 1;
                                    end
                                end
                            end
                        end

                        E_BRACE: begin
                            // Find matching } for ${...}
                            if (scan_idx == 0) begin
                                brace_depth <= 1;
                                in_quote <= 0;
                                in_backtick <= 0;
                                scan_idx <= 1;
                            end else if (brace_depth == 0) begin
                                // Found closing }
                                // Extract Inner Expression (length = scan_idx - 1)
                                for (i=0; i<32; i=i+1) begin
                                    if (i < (scan_idx - 1)) temp_val_str[i*8 +: 8] <= current_expr_str[(current_pos + i)*8 +: 8];
                                end
                                temp_val_len <= scan_idx - 1;
                                // Push
                                if (sp < MAX_TEMPLATE_DEPTH) begin
                                    stack_res_str[sp] <= eval_result_str;
                                    stack_res_len[sp] <= eval_result_len;
                                    stack_expr_str[sp] <= current_expr_str;
                                    stack_expr_len[sp] <= current_expr_len;
                                    stack_expr_pos[sp] <= current_pos + scan_idx + 1; // Resume after }
                                    sp <= sp + 1;
                                    // Set Context Inner
                                    current_expr_str <= temp_val_str;
                                    current_expr_len <= scan_idx - 1;
                                    current_pos <= 0;
                                    eval_result_str <= 0;
                                    eval_result_len <= 0;
                                    eval_step <= E_INIT;
                                    scan_idx <= 0;
                                end else begin
                                    state <= ERROR_STATE;
                                end
                            end else begin
                                // Scan char
                                if (current_pos + scan_idx >= current_expr_len) begin
                                    state <= ERROR_STATE; // No closing brace
                                end else begin
                                    // Update Flags & Depth
                                    if (!(in_quote || in_backtick)) begin
                                        if (current_expr_str[(current_pos + scan_idx)*8 +: 8] == 8'h7B) brace_depth <= brace_depth + 1;
                                        if (current_expr_str[(current_pos + scan_idx)*8 +: 8] == 8'h7D) brace_depth <= brace_depth - 1;
                                    end
                                    if (current_expr_str[(current_pos + scan_idx)*8 +: 8] == 8'h22 && !in_backtick) in_quote <= !in_quote;
                                    if (current_expr_str[(current_pos + scan_idx)*8 +: 8] == 8'h60 && !in_quote) in_backtick <= !in_backtick;
                                    scan_idx <= scan_idx + 1;
                                end
                            end
                        end

                        E_RESUME: begin
                            // Pop and Merge
                            eval_result_str <= stack_res_str[sp-1] | (eval_result_str >> (stack_res_len[sp-1] * 8));
                            eval_result_len <= stack_res_len[sp-1] + eval_result_len;
                            current_expr_str <= stack_expr_str[sp-1];
                            current_expr_len <= stack_expr_len[sp-1];
                            current_pos <= stack_expr_pos[sp-1];
                            sp <= sp - 1;
                            eval_step <= E_TMPL; // Return to template scanner
                        end

                        E_DONE: begin
                            if (call_return_state == 0) state <= UPDATE_VAR;
                            else begin
                                result <= eval_result_str;
                                result_length <= eval_result_len;
                                state <= FINISHED;
                            end
                        end
                    endcase
                end

                UPDATE_VAR: begin
                    // Check if variable exists
                    lookup_found <= 0;
                    lookup_idx <= 0;
                    for (i=0; i<MAX_VARS; i=i+1) begin
                        if (var_name_len[i] == name_len && !lookup_found) begin
                            if (temp_name_str[79:0] == var_names[i]) begin
                                lookup_found <= 1;
                                lookup_idx <= i;
                            end
                        end
                    end
                    if (lookup_found) begin
                        var_values[lookup_idx] <= eval_result_str[255:128];
                        var_val_len[lookup_idx] <= eval_result_len;
                    end else begin
                        if (var_count < MAX_VARS) begin
                            var_names[var_count] <= temp_name_str[79:0];
                            var_name_len[var_count] <= name_len;
                            var_values[var_count] <= eval_result_str[255:128];
                            var_val_len[var_count] <= eval_result_len;
                            var_count <= var_count + 1;
                        end else begin
                            state <= ERROR_STATE;
                        end
                    end
                    if (state != ERROR_STATE) state <= FINISHED;
                end

                FINISHED: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end

                ERROR_STATE: begin
                    error <= 1;
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule