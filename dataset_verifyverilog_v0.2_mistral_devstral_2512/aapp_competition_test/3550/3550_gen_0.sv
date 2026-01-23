module nenscript_evaluator (
    input clk,
    input rst_n,
    input start,
    input cmd_type,
    input [255:0] line_buffer [0:79],
    input [7:0] line_length,
    output reg [255:0] result,
    output reg [7:0] result_length,
    output reg done,
    output reg error
);

    // Parameters
    localparam NUM_VARS = 8;
    localparam MAX_NAME_LEN = 10;
    localparam MAX_VAL_LEN = 16;
    localparam MAX_DEPTH = 3;

    // Variable table structure
    typedef struct {
        logic [7:0] name [0:MAX_NAME_LEN-1];
        logic [7:0] value [0:MAX_VAL_LEN-1];
        logic [5:0] name_length;
        logic [7:0] value_length;
    } var_entry_t;

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        PARSE_DECL,
        PARSE_PRINT,
        EVAL_EXPR,
        UPDATE_VAR,
        FINISHED
    } state_t;

    // FSM state
    state_t current_state, next_state;

    // Variable table
    var_entry_t var_table [0:NUM_VARS-1];
    logic [2:0] next_var_slot;

    // Expression evaluation stack
    typedef struct {
        logic [7:0] pos;
        logic [1:0] depth;
        logic [7:0] result_buf [0:MAX_VAL_LEN-1];
        logic [7:0] result_len;
    } eval_stack_t;

    eval_stack_t eval_stack [0:MAX_DEPTH-1];
    logic [1:0] stack_ptr;

    // Current parsing context
    logic [7:0] parse_pos;
    logic [7:0] expr_start, expr_end;
    logic [7:0] temp_result [0:MAX_VAL_LEN-1];
    logic [7:0] temp_len;

    // Temporary storage for parsing
    logic [7:0] current_char;
    logic [7:0] name_buf [0:MAX_NAME_LEN-1];
    logic [5:0] name_len;

    // Initialize variable table
    integer i, j;
    initial begin
        for (i = 0; i < NUM_VARS; i = i + 1) begin
            var_table[i].name_length = 0;
            var_table[i].value_length = 0;
            for (j = 0; j < MAX_NAME_LEN; j = j + 1) begin
                var_table[i].name[j] = 0;
            end
            for (j = 0; j < MAX_VAL_LEN; j = j + 1) begin
                var_table[i].value[j] = 0;
            end
        end
        next_var_slot = 0;
        stack_ptr = 0;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            error <= 0;
            parse_pos <= 0;
            expr_start <= 0;
            expr_end <= 0;
            temp_len <= 0;
            name_len <= 0;
            for (i = 0; i < MAX_VAL_LEN; i = i + 1) begin
                temp_result[i] <= 0;
            end
            for (i = 0; i < MAX_NAME_LEN; i = i + 1) begin
                name_buf[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    if (cmd_type == 0) next_state = PARSE_DECL;
                    else next_state = PARSE_PRINT;
                end
            end
            
            PARSE_DECL: begin
                // Parse "var <name> = <expr>;"
                if (parse_pos < line_length) begin
                    current_char = line_buffer[0][parse_pos];
                    
                    // Skip whitespace
                    if (current_char == 8'd32) begin
                        parse_pos = parse_pos + 1;
                    end
                    // Parse "var"
                    else if (parse_pos == 0 && current_char == 8'd118) begin
                        parse_pos = parse_pos + 1;
                    end
                    // Parse variable name
                    else if (name_len < MAX_NAME_LEN && 
                            (current_char >= 8'd97 && current_char <= 8'd122 || current_char == 8'd95)) begin
                        name_buf[name_len] = current_char;
                        name_len = name_len + 1;
                        parse_pos = parse_pos + 1;
                    end
                    // Parse "="
                    else if (current_char == 8'd61) begin
                        parse_pos = parse_pos + 1;
                        expr_start = parse_pos;
                    end
                    // Parse expression until ";"
                    else if (current_char == 8'd59) begin
                        expr_end = parse_pos - 1;
                        next_state = EVAL_EXPR;
                    end
                    else begin
                        parse_pos = parse_pos + 1;
                    end
                end else begin
                    error = 1;
                    next_state = IDLE;
                end
            end
            
            PARSE_PRINT: begin
                // Parse "print <expr>;"
                if (parse_pos < line_length) begin
                    current_char = line_buffer[0][parse_pos];
                    
                    // Skip whitespace
                    if (current_char == 8'd32) begin
                        parse_pos = parse_pos + 1;
                    end
                    // Parse "print"
                    else if (parse_pos == 0 && current_char == 8'd112) begin
                        parse_pos = parse_pos + 1;
                    end
                    // Parse expression until ";"
                    else if (current_char == 8'd59) begin
                        expr_end = parse_pos - 1;
                        next_state = EVAL_EXPR;
                    end
                    else begin
                        parse_pos = parse_pos + 1;
                    end
                end else begin
                    error = 1;
                    next_state = IDLE;
                end
            end
            
            EVAL_EXPR: begin
                // Evaluate expression
                if (stack_ptr < MAX_DEPTH) begin
                    // Initialize stack frame
                    eval_stack[stack_ptr].pos = expr_start;
                    eval_stack[stack_ptr].depth = stack_ptr;
                    eval_stack[stack_ptr].result_len = 0;
                    
                    // Evaluate expression
                    logic [7:0] expr_type = line_buffer[0][expr_start];
                    
                    // String literal
                    if (expr_type == 8'd34) begin
                        logic [7:0] pos = expr_start + 1;
                        logic [7:0] len = 0;
                        
                        while (pos <= expr_end && line_buffer[0][pos] != 8'd34) begin
                            temp_result[len] = line_buffer[0][pos];
                            len = len + 1;
                            pos = pos + 1;
                        end
                        temp_len = len;
                        
                        if (cmd_type == 0) next_state = UPDATE_VAR;
                        else next_state = FINISHED;
                    end
                    // Template literal
                    else if (expr_type == 8'd96) begin
                        logic [7:0] pos = expr_start + 1;
                        logic [7:0] len = 0;
                        
                        while (pos <= expr_end && line_buffer[0][pos] != 8'd96) begin
                            if (line_buffer[0][pos] == 8'd36 && line_buffer[0][pos+1] == 8'd123) begin
                                // Handle ${...}
                                pos = pos + 2;
                                logic [7:0] expr_start_temp = pos;
                                logic [7:0] expr_end_temp = pos;
                                
                                while (pos <= expr_end && line_buffer[0][pos] != 8'd125) begin
                                    expr_end_temp = pos;
                                    pos = pos + 1;
                                end
                                
                                // Recursively evaluate
                                stack_ptr = stack_ptr + 1;
                                eval_stack[stack_ptr].pos = expr_start_temp;
                                eval_stack[stack_ptr].depth = stack_ptr;
                                
                                // For simplicity, assume evaluation completes in one cycle
                                // In real implementation, this would be a multi-cycle process
                                
                                stack_ptr = stack_ptr - 1;
                                pos = pos + 1;
                            end else begin
                                temp_result[len] = line_buffer[0][pos];
                                len = len + 1;
                                pos = pos + 1;
                            end
                        end
                        temp_len = len;
                        
                        if (cmd_type == 0) next_state = UPDATE_VAR;
                        else next_state = FINISHED;
                    end
                    // Variable reference
                    else if (expr_type >= 8'd97 && expr_type <= 8'd122 || expr_type == 8'd95) begin
                        logic [7:0] var_name [0:MAX_NAME_LEN-1];
                        logic [5:0] var_len = 0;
                        logic [7:0] pos = expr_start;
                        
                        while (pos <= expr_end && var_len < MAX_NAME_LEN && 
                              (line_buffer[0][pos] >= 8'd97 && line_buffer[0][pos] <= 8'd122 || 
                               line_buffer[0][pos] == 8'd95)) begin
                            var_name[var_len] = line_buffer[0][pos];
                            var_len = var_len + 1;
                            pos = pos + 1;
                        end
                        
                        // Lookup variable
                        logic found = 0;
                        for (i = 0; i < NUM_VARS; i = i + 1) begin
                            if (var_table[i].name_length == var_len) begin
                                found = 1;
                                for (j = 0; j < var_len; j = j + 1) begin
                                    if (var_table[i].name[j] != var_name[j]) begin
                                        found = 0;
                                    end
                                end
                                if (found) begin
                                    temp_len = var_table[i].value_length;
                                    for (j = 0; j < temp_len; j = j + 1) begin
                                        temp_result[j] = var_table[i].value[j];
                                    end
                                    break;
                                end
                            end
                        end
                        
                        if (!found) error = 1;
                        
                        if (cmd_type == 0) next_state = UPDATE_VAR;
                        else next_state = FINISHED;
                    end
                    else begin
                        error = 1;
                        next_state = IDLE;
                    end
                end else begin
                    error = 1;
                    next_state = IDLE;
                end
            end
            
            UPDATE_VAR: begin
                // Store result in variable table
                if (next_var_slot < NUM_VARS) begin
                    var_table[next_var_slot].name_length = name_len;
                    var_table[next_var_slot].value_length = temp_len;
                    
                    for (i = 0; i < name_len; i = i + 1) begin
                        var_table[next_var_slot].name[i] = name_buf[i];
                    end
                    
                    for (i = 0; i < temp_len; i = i + 1) begin
                        var_table[next_var_slot].value[i] = temp_result[i];
                    end
                    
                    next_var_slot = next_var_slot + 1;
                    next_state = IDLE;
                end else begin
                    error = 1;
                    next_state = IDLE;
                end
            end
            
            FINISHED: begin
                // Output result
                result_length = temp_len;
                for (i = 0; i < temp_len; i = i + 1) begin
                    result[i] = temp_result[i];
                end
                done = 1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule