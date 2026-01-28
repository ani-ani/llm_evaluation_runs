module triple_correlation_detector(
    input clk,
    input rst_n,
    input start,
    input [3:0] seq_len,
    input [3:0] seq_din,
    input seq_we,
    output reg done,
    output reg found,
    output reg [3:0] a_out,
    output reg [3:0] b_out,
    output reg [3:0] c_out,
    output reg [5:0] n_out,
    output reg [5:0] m_out
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] SEARCH  = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Sequence memory (64x4-bit)
    reg [3:0] seq_mem [0:63];
    reg [5:0] seq_ptr;
    reg [5:0] seq_count;

    // Search parameters
    reg [3:0] a, b, c;
    reg [5:0] n, m;
    reg [5:0] i, j, k;

    // Correlation tracking
    reg [7:0] correlation_count;
    reg [7:0] max_correlation_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Result tracking
    reg [3:0] best_a, best_b, best_c;
    reg [5:0] best_n, best_m;
    reg [5:0] best_i;
    reg found_correlation;

    // Threshold calculation
    wire [7:0] threshold = (seq_len >> 5) + 8'd1;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            seq_ptr <= 6'd0;
            seq_count <= 6'd0;
            a <= 4'd0;
            b <= 4'd0;
            c <= 4'd0;
            n <= 6'd0;
            m <= 6'd0;
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            correlation_count <= 8'd0;
            max_correlation_count <= 8'd0;
            cycle_count <= 8'd0;
            best_a <= 4'd0;
            best_b <= 4'd0;
            best_c <= 4'd0;
            best_n <= 6'd0;
            best_m <= 6'd0;
            best_i <= 6'd0;
            found_correlation <= 1'b0;
            done <= 1'b0;
            found <= 1'b0;
            a_out <= 4'd0;
            b_out <= 4'd0;
            c_out <= 4'd0;
            n_out <= 6'd0;
            m_out <= 6'd0;
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
                if (seq_we && seq_ptr < seq_len) begin
                    next_state = LOAD;
                end else if (seq_ptr >= seq_len) begin
                    next_state = SEARCH;
                end
            end

            SEARCH: begin
                if (cycle_count >= MAX_CYCLES || (found_correlation && correlation_count >= threshold)) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SEARCH;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load phase logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_ptr <= 6'd0;
            seq_count <= 6'd0;
        end else if (state == LOAD && seq_we && seq_ptr < seq_len) begin
            seq_mem[seq_ptr] <= seq_din;
            seq_ptr <= seq_ptr + 6'd1;
            seq_count <= seq_count + 6'd1;
        end
    end

    // Search phase logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
            correlation_count <= 8'd0;
            found_correlation <= 1'b0;
        end else if (state == SEARCH) begin
            cycle_count <= cycle_count + 8'd1;

            // Search for correlations
            if (!found_correlation) begin
                // Search pattern 1: a(n)b(m)c
                if (i < seq_len && n >= 6'd1 && n < 6'd64 && i + n < seq_len && m >= 6'd1 && m < 6'd64 && i + n + m < seq_len) begin
                    a = seq_mem[i];
                    b = seq_mem[i + n];
                    c = seq_mem[i + n + m];

                    // Count occurrences
                    for (j = 6'd0; j < seq_len; j = j + 6'd1) begin
                        if (j + n < seq_len && j + n + m < seq_len && 
                            seq_mem[j] == a && seq_mem[j + n] == b && seq_mem[j + n + m] == c) begin
                            correlation_count = correlation_count + 8'd1;
                        end
                    end

                    // Check if this is the best correlation
                    if (correlation_count >= threshold && (!found_correlation || i < best_i || (i == best_i && n < best_n) || (i == best_i && n == best_n && m < best_m))) begin
                        best_a = a;
                        best_b = b;
                        best_c = c;
                        best_n = n;
                        best_m = m;
                        best_i = i;
                        found_correlation = 1'b1;
                    end

                    // Increment counters
                    if (m < 6'd63) begin
                        m = m + 6'd1;
                    end else if (n < 6'd63) begin
                        n = n + 6'd1;
                        m = 6'd1;
                    end else if (i < seq_len - 1) begin
                        i = i + 6'd1;
                        n = 6'd1;
                        m = 6'd1;
                    end
                end
                // Search pattern 2: b(m)c with a at b-n
                else if (j < seq_len && m >= 6'd1 && m < 6'd64 && j + m < seq_len && n >= 6'd1 && n < 6'd64 && j >= n) begin
                    b = seq_mem[j];
                    c = seq_mem[j + m];
                    a = seq_mem[j - n];

                    // Count occurrences
                    for (k = 6'd0; k < seq_len; k = k + 6'd1) begin
                        if (k + m < seq_len && k >= n && 
                            seq_mem[k] == b && seq_mem[k + m] == c && seq_mem[k - n] == a) begin
                            correlation_count = correlation_count + 8'd1;
                        end
                    end

                    // Check if this is the best correlation
                    if (correlation_count >= threshold && (!found_correlation || j - n < best_i || (j - n == best_i && n < best_n) || (j - n == best_i && n == best_n && m < best_m))) begin
                        best_a = a;
                        best_b = b;
                        best_c = c;
                        best_n = n;
                        best_m = m;
                        best_i = j - n;
                        found_correlation = 1'b1;
                    end

                    // Increment counters
                    if (m < 6'd63) begin
                        m = m + 6'd1;
                    end else if (n < 6'd63) begin
                        n = n + 6'd1;
                        m = 6'd1;
                    end else if (j < seq_len - 1) begin
                        j = j + 6'd1;
                        n = 6'd1;
                        m = 6'd1;
                    end
                end
                // Search pattern 3: a(n+m)c with b at a+n
                else if (k < seq_len && n >= 6'd1 && n < 6'd64 && m >= 6'd1 && m < 6'd64 && k + n + m < seq_len) begin
                    a = seq_mem[k];
                    c = seq_mem[k + n + m];
                    b = seq_mem[k + n];

                    // Count occurrences
                    for (i = 6'd0; i < seq_len; i = i + 6'd1) begin
                        if (i + n + m < seq_len && 
                            seq_mem[i] == a && seq_mem[i + n + m] == c && seq_mem[i + n] == b) begin
                            correlation_count = correlation_count + 8'd1;
                        end
                    end

                    // Check if this is the best correlation
                    if (correlation_count >= threshold && (!found_correlation || k < best_i || (k == best_i && n < best_n) || (k == best_i && n == best_n && m < best_m))) begin
                        best_a = a;
                        best_b = b;
                        best_c = c;
                        best_n = n;
                        best_m = m;
                        best_i = k;
                        found_correlation = 1'b1;
                    end

                    // Increment counters
                    if (m < 6'd63) begin
                        m = m + 6'd1;
                    end else if (n < 6'd63) begin
                        n = n + 6'd1;
                        m = 6'd1;
                    end else if (k < seq_len - 1) begin
                        k = k + 6'd1;
                        n = 6'd1;
                        m = 6'd1;
                    end
                end
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            found <= 1'b0;
            a_out <= 4'd0;
            b_out <= 4'd0;
            c_out <= 4'd0;
            n_out <= 6'd0;
            m_out <= 6'd0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
            found <= found_correlation;
            a_out <= best_a;
            b_out <= best_b;
            c_out <= best_c;
            n_out <= best_n;
            m_out <= best_m;
        end else begin
            done <= 1'b0;
        end
    end

endmodule