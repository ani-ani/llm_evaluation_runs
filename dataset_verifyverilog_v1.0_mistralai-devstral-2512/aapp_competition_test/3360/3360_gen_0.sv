module cfg_search(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [31:0] cfg_rules,
    input [3:0] input_len,
    input text_mode,
    output reg [3:0] result_start,
    output reg [3:0] result_len,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_TEXT = 3'd1;
    localparam [2:0] LOAD_RULES = 3'd2;
    localparam [2:0] PARSE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] char_index;
    reg [3:0] rule_index;
    reg [3:0] i, j, k;
    reg [3:0] best_start, best_len;
    reg [3:0] current_len;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal storage
    reg [7:0] text_buffer [0:15];
    reg [25:0] rule_head [0:15];
    reg [23:0] rule_prod [0:15];
    reg [25:0] parse_table [0:15][0:15];

    // Temporary registers
    reg [25:0] temp_mask;
    reg [7:0] temp_char;
    reg [23:0] temp_prod;
    reg [25:0] temp_combined;
    reg match_found;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            char_index <= 4'd0;
            rule_index <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            best_start <= 4'd0;
            best_len <= 4'd0;
            current_len <= 4'd0;
            cycle_count <= 4'd0;
            done <= 1'b0;
            busy <= 1'b0;

            // Initialize text buffer
            integer idx;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                text_buffer[idx] <= 8'd0;
            end

            // Initialize rule storage
            for (idx = 0; idx < 16; idx = idx + 1) begin
                rule_head[idx] <= 26'd0;
                rule_prod[idx] <= 24'd0;
            end

            // Initialize parse table
            for (idx = 0; idx < 16; idx = idx + 1) begin
                integer jdx;
                for (jdx = 0; jdx < 16; jdx = jdx + 1) begin
                    parse_table[idx][jdx] <= 26'd0;
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        if (text_mode) begin
                            next_state <= LOAD_TEXT;
                            char_index <= 4'd0;
                        end else begin
                            next_state <= LOAD_RULES;
                            rule_index <= 4'd0;
                        end
                        busy <= 1'b1;
                    end
                end

                LOAD_TEXT: begin
                    if (char_index < input_len) begin
                        text_buffer[char_index] <= char_in;
                        char_index <= char_index + 4'd1;
                    end else begin
                        next_state <= PARSE;
                        i <= 4'd0;
                        j <= 4'd0;
                        current_len <= 4'd1;
                        cycle_count <= 4'd0;
                    end
                end

                LOAD_RULES: begin
                    if (rule_index < 16) begin
                        rule_head[rule_index] <= cfg_rules[31:24];
                        rule_prod[rule_index] <= cfg_rules[23:0];
                        rule_index <= rule_index + 4'd1;
                    end else begin
                        next_state <= IDLE;
                        busy <= 1'b0;
                    end
                end

                PARSE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        // Initialize diagonal
                        if (current_len == 4'd1) begin
                            if (i < input_len) begin
                                // Check terminal rules
                                temp_mask <= 26'd0;
                                integer ridx;
                                for (ridx = 0; ridx < 16; ridx = ridx + 1) begin
                                    temp_prod <= rule_prod[ridx];
                                    // Check if production is single terminal
                                    if (temp_prod[23:16] == 8'd0 && temp_prod[15:8] == 8'd0 && temp_prod[7:0] != 8'd0) begin
                                        if (text_buffer[i] == temp_prod[7:0]) begin
                                            temp_mask[rule_head[ridx] - 8'd65] <= 1'b1;
                                        end
                                    end
                                end
                                parse_table[i][i] <= temp_mask;
                                i <= i + 4'd1;
                                if (i >= input_len) begin
                                    i <= 4'd0;
                                    j <= 4'd0;
                                    current_len <= 4'd2;
                                end
                            end
                        end
                        // Combine spans
                        else begin
                            if (i < input_len && j < input_len && (i + current_len - 4'd1) < input_len) begin
                                temp_mask <= 26'd0;
                                // Check all possible splits
                                integer split;
                                for (split = i; split < (i + current_len - 4'd1); split = split + 1) begin
                                    temp_combined <= parse_table[i][split] & parse_table[split + 4'd1][i + current_len - 4'd1];
                                    // Check rules that match this combination
                                    integer ridx;
                                    for (ridx = 0; ridx < 16; ridx = ridx + 1) begin
                                        temp_prod <= rule_prod[ridx];
                                        // Check if production matches two variables
                                        if (temp_prod[23:16] != 8'd0 && temp_prod[15:8] != 8'd0 && temp_prod[7:0] == 8'd0) begin
                                            if (temp_combined[temp_prod[23:16] - 8'd65] && temp_combined[temp_prod[15:8] - 8'd65]) begin
                                                temp_mask[rule_head[ridx] - 8'd65] <= 1'b1;
                                            end
                                        end
                                    end
                                end
                                parse_table[i][i + current_len - 4'd1] <= temp_mask;

                                // Check if start variable (S) is present
                                if (temp_mask[8'd83 - 8'd65]) begin
                                    if (current_len > best_len) begin
                                        best_start <= i;
                                        best_len <= current_len;
                                    end
                                end

                                // Move to next position
                                j <= j + 4'd1;
                                if (j >= (input_len - current_len + 4'd1)) begin
                                    j <= 4'd0;
                                    i <= i + 4'd1;
                                    if (i >= (input_len - current_len + 4'd1)) begin
                                        i <= 4'd0;
                                        current_len <= current_len + 4'd1;
                                        if (current_len > input_len) begin
                                            next_state <= FINISH;
                                        end
                                    end
                                end
                            end else begin
                                next_state <= FINISH;
                            end
                        end
                    end
                end

                FINISH: begin
                    result_start <= best_start;
                    result_len <= best_len;
                    done <= 1'b1;
                    next_state <= IDLE;
                    busy <= 1'b0;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule