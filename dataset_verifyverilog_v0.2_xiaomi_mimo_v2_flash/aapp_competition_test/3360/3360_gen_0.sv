module cfg_search(
    input clk,
    input rst_n,
    input start,
    input [4:0] rule_count,
    input [5:0][39:0] rule_data,
    input [127:0] text_data,
    output reg [7:0] result_start,
    output reg [7:0] result_length,
    output reg [127:0] result_substr,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam PARSE = 3'b010;
    localparam PROCESS = 3'b100;
    localparam DONE_STATE = 3'b000;

    reg [2:0] state;
    reg [2:0] next_state;

    // Storage
    reg [4:0] valid_rules;
    reg [25:0] rule_head [0:4];
    reg [7:0] rule_prod_len [0:4];
    reg [23:0] rule_prod_data [0:4];
    reg [4:0] parse_idx;
    reg [127:0] text_reg;

    // DP Table: [0..15] start, [0..15] len_index
    // Address = {start[3:0], len_index[3:0]}
    reg [25:0] dp_table [0:255];

    // Processing Registers
    reg [3:0] len;
    reg [3:0] start_idx;
    reg [4:0] rule_idx;
    reg [1:0] combo_idx;
    reg [25:0] current_vars;
    reg [3:0] split_pos;
    
    // Result Registers
    reg [7:0] best_len;
    reg [7:0] best_start;
    reg [127:0] best_substr;
    
    // Helper Wires
    wire [25:0] current_head = rule_head[rule_idx];
    wire [7:0] current_len = rule_prod_len[rule_idx];
    wire [23:0] current_prod = rule_prod_data[rule_idx];
    wire [7:0] char0 = current_prod[23:16];
    wire [7:0] char1 = current_prod[15:8];
    wire [7:0] char2 = current_prod[7:0];
    wire [7:0] t_start = text_reg[(start_idx*8)+:8];
    wire [7:0] t_end = text_reg[((start_idx + len - 1)*8)+:8];
    
    // Start Pulse
    reg start_prev;
    wire start_pulse = start & ~start_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_prev <= 0;
        else start_prev <= start;
    end

    // State Transition
    always @(*) begin
        case (state)
            IDLE: next_state = start_pulse ? PARSE : IDLE;
            PARSE: next_state = (parse_idx >= rule_count) ? PROCESS : PARSE;
            PROCESS: next_state = (len == 4'd16 && start_idx == 0 && rule_idx >= rule_count && combo_idx == 2) ? DONE_STATE : PROCESS;
            DONE_STATE: next_state = start_pulse ? IDLE : DONE_STATE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // PARSE Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parse_idx <= 0;
            valid_rules <= 0;
        end else if (state == IDLE && start_pulse) begin
            parse_idx <= 0;
            valid_rules <= 0;
            text_reg <= text_data;
        end else if (state == PARSE) begin
            if (parse_idx < rule_count) begin
                valid_rules[parse_idx] <= 1'b1;
                // Mapping A-Z to bit vector. 'A' is 0x41.
                rule_head[parse_idx] <= 1 << (rule_data[parse_idx][39:32] - 8'h41);
                rule_prod_len[parse_idx] <= rule_data[parse_idx][31:24];
                rule_prod_data[parse_idx] <= rule_data[parse_idx][23:0];
                parse_idx <= parse_idx + 1;
            end
        end
    end

    // PROCESS Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            len <= 1; start_idx <= 0; rule_idx <= 0; combo_idx <= 0;
            current_vars <= 0; best_len <= 0; split_pos <= 1;
        end else if (state == IDLE && start_pulse) begin
            len <= 1; start_idx <= 0; rule_idx <= 0; combo_idx <= 0;
            current_vars <= 0; best_len <= 0; split_pos <= 1;
        end else if (state == PROCESS) begin
            
            // Reset accumulator for new cell
            if (rule_idx == 0 && combo_idx == 0) begin
                current_vars <= 0;
                split_pos <= 1;
            end
            
            if (rule_idx < rule_count) begin
                // Rule Processing
                
                if (combo_idx == 0) begin
                    // Check Empty
                    if (current_len == 0) combo_idx <= 2;
                    // Check Terminal
                    else if (current_len == 1 && char0 >= 8'h61 && char0 <= 8'h7a) begin
                        if (len == 1 && t_start == char0) current_vars <= current_vars | current_head;
                        combo_idx <= 2;
                    end
                    else if (current_len >= 2) combo_idx <= 1; // Move to check
                    else combo_idx <= 2;
                end
                
                else if (combo_idx == 1) begin
                    // Check patterns
                    // VarTerm (Aa)
                    if (char0 >= 8'h41 && char0 <= 8'h5a && char1 >= 8'h61 && char1 <= 8'h7a) begin
                        if (len >= 2) begin
                            if (dp_table[{start_idx, len-2}] & (1 << (char0 - 8'h41)) && t_end == char1)
                                current_vars <= current_vars | current_head;
                        end
                        combo_idx <= 2;
                    end
                    // TermVar (aA)
                    else if (char0 >= 8'h61 && char0 <= 8'h7a && char1 >= 8'h41 && char1 <= 8'h5a) begin
                        if (len >= 2) begin
                            if (t_start == char0 && (dp_table[{start_idx+1, len-2}] & (1 << (char1 - 8'h41))))
                                current_vars <= current_vars | current_head;
                        end
                        combo_idx <= 2;
                    end
                    // TermVarTerm (aAa)
                    else if (char0 >= 8'h61 && char0 <= 8'h7a && char1 >= 8'h41 && char1 <= 8'h5a && char2 >= 8'h61 && char2 <= 8'h7a) begin
                        if (len >= 3) begin
                            if (t_start == char0 && t_end == char2 && (dp_table[{start_idx+1, len-3}] & (1 << (char1 - 8'h41))))
                                current_vars <= current_vars | current_head;
                        end
                        combo_idx <= 2;
                    end
                    // VarVar (AA)
                    else if (char0 >= 8'h41 && char0 <= 8'h5a && char1 >= 8'h41 && char1 <= 8'h5a) begin
                        if (len >= 2) begin
                            if ( (dp_table[{start_idx, split_pos-1}] & (1 << (char0 - 8'h41))) &&
                                 (dp_table[{start_idx+split_pos, len-split_pos-1}] & (1 << (char1 - 8'h41))) ) begin
                                current_vars <= current_vars | current_head;
                            end
                            if (split_pos < len - 1) begin
                                split_pos <= split_pos + 1;
                                combo_idx <= 1; // Stay
                            end else begin
                                combo_idx <= 2;
                            end
                        end else begin
                            combo_idx <= 2;
                        end
                    end
                    else combo_idx <= 2;
                end
                
                else if (combo_idx == 2) begin
                    // Next Rule
                    rule_idx <= rule_idx + 1;
                    combo_idx <= 0;
                    split_pos <= 1;
                end
                
            end else begin
                // Cell Done
                dp_table[{start_idx, len-1}] <= current_vars;
                
                // Check Match (S = 0x53 = bit 18)
                if (current_vars[18]) begin
                    if (len > best_len) begin
                        best_len <= len;
                        best_start <= start_idx;
                        best_substr <= (text_reg >> (start_idx * 8)) << ((16 - len) * 8);
                    end
                end
                
                // Next Cell
                if (start_idx < 16 - len) begin
                    start_idx <= start_idx + 1;
                end else begin
                    start_idx <= 0;
                    if (len < 16) len <= len + 1;
                end
                
                rule_idx <= 0;
                combo_idx <= 0;
                current_vars <= 0;
                split_pos <= 1;
            end
        end
    end

    // DONE Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_start <= 0; result_length <= 0; result_substr <= 0; done <= 0;
        end else if (state == DONE_STATE) begin
            result_start <= best_start;
            result_length <= best_len;
            result_substr <= best_substr;
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule
