module string_prefix_swap(
    input clk,
    input rst_n,
    input start,
    input [7:0] s_char_i,
    input [7:0] t_char_i,
    input [3:0] len_s,
    input [3:0] len_t,
    output reg done,
    output reg [5:0] op_count,
    output reg [3:0] op_s_len,
    output reg [3:0] op_t_len,
    output reg valid_op
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT  = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] s_index, t_index;
    reg [3:0] op_index;
    reg [3:0] s_len_reg, t_len_reg;
    reg [7:0] s_mem [0:15];
    reg [7:0] t_mem [0:15];
    reg [3:0] op_s_mem [0:63];
    reg [3:0] op_t_mem [0:63];
    reg [5:0] op_count_reg;
    reg [3:0] current_s_len, current_t_len;
    reg [3:0] last_a_s, last_b_s;
    reg [3:0] last_a_t, last_b_t;
    reg found_s, found_t;
    reg [3:0] i, j;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            s_index <= 4'd0;
            t_index <= 4'd0;
            op_index <= 4'd0;
            op_count_reg <= 6'd0;
            done <= 1'b0;
            valid_op <= 1'b0;
            s_len_reg <= 4'd0;
            t_len_reg <= 4'd0;
            current_s_len <= 4'd0;
            current_t_len <= 4'd0;
            // Initialize memories
            for (i = 0; i < 16; i = i + 1) begin
                s_mem[i] <= 8'd0;
                t_mem[i] <= 8'd0;
            end
            for (i = 0; i < 64; i = i + 1) begin
                op_s_mem[i] <= 4'd0;
                op_t_mem[i] <= 4'd0;
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
                    next_state = LOAD;
                end
            end
            LOAD: begin
                if (s_index == s_len_reg && t_index == t_len_reg) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if (op_count_reg >= 6'd64 || (current_s_len == 4'd0 && current_t_len == 4'd0)) begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                if (op_index == op_count_reg) begin
                    done <= 1'b1;
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Load strings
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_index <= 4'd0;
            t_index <= 4'd0;
            s_len_reg <= 4'd0;
            t_len_reg <= 4'd0;
        end else if (state == LOAD) begin
            if (s_index < len_s) begin
                s_mem[s_index] <= s_char_i;
                s_index <= s_index + 4'd1;
            end
            if (t_index < len_t) begin
                t_mem[t_index] <= t_char_i;
                t_index <= t_index + 4'd1;
            end
            if (s_index == len_s && t_index == len_t) begin
                s_len_reg <= len_s;
                t_len_reg <= len_t;
                current_s_len <= len_s;
                current_t_len <= len_t;
            end
        end
    end

    // Compute operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_count_reg <= 6'd0;
            current_s_len <= 4'd0;
            current_t_len <= 4'd0;
        end else if (state == COMPUTE) begin
            // Find last 'a' in s and last 'b' in t
            last_a_s = 4'd0;
            last_b_s = 4'd0;
            last_a_t = 4'd0;
            last_b_t = 4'd0;
            found_s = 1'b0;
            found_t = 1'b0;

            // Scan s for last 'a' and last 'b'
            for (i = current_s_len - 4'd1; i >= 4'd0; i = i - 4'd1) begin
                if (s_mem[i] == 8'd97) begin  // 'a'
                    last_a_s = i + 4'd1;
                    found_s = 1'b1;
                end
                if (s_mem[i] == 8'd98) begin  // 'b'
                    last_b_s = i + 4'd1;
                end
            end

            // Scan t for last 'a' and last 'b'
            for (i = current_t_len - 4'd1; i >= 4'd0; i = i - 4'd1) begin
                if (t_mem[i] == 8'd97) begin  // 'a'
                    last_a_t = i + 4'd1;
                end
                if (t_mem[i] == 8'd98) begin  // 'b'
                    last_b_t = i + 4'd1;
                    found_t = 1'b1;
                end
            end

            // Greedy operation selection
            if (found_s && found_t && op_count_reg < 6'd64) begin
                // Case 1: s ends with 'b', t ends with 'a'
                if (s_mem[current_s_len - 4'd1] == 8'd98 && 
                    t_mem[current_t_len - 4'd1] == 8'd97) begin
                    op_s_mem[op_count_reg] = last_a_s;
                    op_t_mem[op_count_reg] = last_b_t;
                    op_count_reg <= op_count_reg + 6'd1;
                    current_s_len <= last_a_s;
                    current_t_len <= last_b_t;
                end
                // Case 2: s ends with 'a', t ends with 'b'
                else if (s_mem[current_s_len - 4'd1] == 8'd97 && 
                         t_mem[current_t_len - 4'd1] == 8'd98) begin
                    op_s_mem[op_count_reg] = last_b_s;
                    op_t_mem[op_count_reg] = last_a_t;
                    op_count_reg <= op_count_reg + 6'd1;
                    current_s_len <= last_b_s;
                    current_t_len <= last_a_t;
                end
                // Case 3: s ends with 'b', t ends with 'b'
                else if (s_mem[current_s_len - 4'd1] == 8'd98 && 
                         t_mem[current_t_len - 4'd1] == 8'd98) begin
                    op_s_mem[op_count_reg] = last_a_s;
                    op_t_mem[op_count_reg] = 4'd0;
                    op_count_reg <= op_count_reg + 6'd1;
                    current_s_len <= last_a_s;
                end
                // Case 4: s ends with 'a', t ends with 'a'
                else if (s_mem[current_s_len - 4'd1] == 8'd97 && 
                         t_mem[current_t_len - 4'd1] == 8'd97) begin
                    op_s_mem[op_count_reg] = 4'd0;
                    op_t_mem[op_count_reg] = last_b_t;
                    op_count_reg <= op_count_reg + 6'd1;
                    current_t_len <= last_b_t;
                end
            end
        end
    end

    // Output operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_index <= 4'd0;
            valid_op <= 1'b0;
        end else if (state == OUTPUT) begin
            if (op_index < op_count_reg) begin
                op_s_len <= op_s_mem[op_index];
                op_t_len <= op_t_mem[op_index];
                valid_op <= 1'b1;
                op_index <= op_index + 4'd1;
            end else begin
                valid_op <= 1'b0;
            end
        end else begin
            valid_op <= 1'b0;
        end
    end

    // Output operation count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_count <= 6'd0;
        end else begin
            op_count <= op_count_reg;
        end
    end

    // Clear done after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == OUTPUT && op_index == op_count_reg) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule