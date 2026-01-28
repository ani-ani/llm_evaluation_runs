module triple_correlation_detector (
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

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] SEARCH = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal signals and registers
    reg [1:0] state, next_state;
    reg [5:0] write_ptr;  // 0-63
    reg [5:0] read_ptr;
    reg [3:0] seq_mem [0:63];  // 64x4-bit memory
    reg [3:0] seq_len_reg;
    reg [7:0] cycle_count;  // Watchdog timer
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Search variables
    reg [3:0] a, b, c;
    reg [5:0] n, m;
    reg [5:0] i, j, k;  // Position counters
    reg [7:0] count_a, count_b, count_c;  // Occurrence counters
    reg [7:0] threshold;
    reg [1:0] search_step;  // 0-3 for different search phases
    reg [5:0] best_n, best_m;
    reg [3:0] best_a, best_b, best_c;
    reg best_found;
    reg [5:0] best_i;  // For earliest occurrence
    reg searching;

    // Memory write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 6'd0;
        end else if (state == LOAD && seq_we) begin
            if (write_ptr < 6'd64) begin
                seq_mem[write_ptr] <= seq_din;
                write_ptr <= write_ptr + 6'd1;
            end
        end
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            searching <= 1'b0;
        end else begin
            state <= next_state;
            if (searching) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = (write_ptr >= {2'b00, seq_len_reg} && seq_len_reg != 4'd0) ? SEARCH : LOAD;
            SEARCH: begin
                if (!best_found && cycle_count < MAX_CYCLES) begin
                    next_state = SEARCH;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Search logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            found <= 1'b0;
            a_out <= 4'd0;
            b_out <= 4'd0;
            c_out <= 4'd0;
            n_out <= 6'd0;
            m_out <= 6'd0;
            threshold <= 8'd0;
            seq_len_reg <= 4'd0;
            best_found <= 1'b0;
            best_a <= 4'd0;
            best_b <= 4'd0;
            best_c <= 4'd0;
            best_n <= 6'd0;
            best_m <= 6'd0;
            best_i <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    cycle_count <= 8'd0;
                    searching <= 1'b0;
                    best_found <= 1'b0;
                    seq_len_reg <= seq_len;
                    // Scale threshold: ceil(p/40)+1 -> (p/32)+1 approx
                    threshold <= (seq_len >> 5) + 8'd1;
                end

                LOAD: begin
                    if (seq_we && write_ptr < 6'd64) begin
                        // Memory written in combinational block
                    end
                end

                SEARCH: begin
                    searching <= 1'b1;

                    // Initialize search parameters
                    if (cycle_count == 8'd0) begin
                        a <= 4'd0;
                        b <= 4'd0;
                        c <= 4'd0;
                        n <= 6'd1;
                        m <= 6'd1;
                        i <= 6'd0;
                        j <= 6'd0;
                        k <= 6'd0;
                        search_step <= 2'd0;
                    end else if (!best_found) begin
                        // Main search loop - iterate through all combinations
                        if (search_step == 2'd0) begin
                            // Phase 1: Check i, i+n, i+n+m
                            if (i < seq_len_reg - 6'd2) begin
                                if (seq_mem[i] == a) begin
                                    if ((i + n) < seq_len_reg && seq_mem[i + n] == b) begin
                                        if ((i + n + m) < seq_len_reg && seq_mem[i + n + m] == c) begin
                                            count_a <= count_a + 8'd1;
                                        end
                                    end
                                end
                                i <= i + 6'd1;
                                if (i >= seq_len_reg - 6'd2) begin
                                    search_step <= 2'd1;
                                    i <= 6'd0;
                                    count_a <= 8'd0;
                                end
                            end
                        end

                        if (search_step == 2'd1) begin
                            // Phase 2: Check j, j+m, j-n for b,c,a
                            if (j < seq_len_reg - 6'd1) begin
                                if (seq_mem[j] == b && (j + m) < seq_len_reg) begin
                                    if (seq_mem[j + m] == c) begin
                                        if (j >= n && seq_mem[j - n] == a) begin
                                            count_b <= count_b + 8'd1;
                                        end
                                    end
                                end
                                j <= j + 6'd1;
                                if (j >= seq_len_reg - 6'd1) begin
                                    search_step <= 2'd2;
                                    j <= 6'd0;
                                    count_b <= 8'd0;
                                end
                            end
                        end

                        if (search_step == 2'd2) begin
                            // Phase 3: Check k, k+n, k+n+m for a,b,c
                            if (k < seq_len_reg - 6'd2) begin
                                if (seq_mem[k] == a && seq_mem[k + n] == b) begin
                                    if ((k + n + m) < seq_len_reg && seq_mem[k + n + m] == c) begin
                                        count_c <= count_c + 8'd1;
                                    end
                                end
                                k <= k + 6'd1;
                                if (k >= seq_len_reg - 6'd2) begin
                                    // Check if this correlation meets threshold
                                    if (count_a >= threshold && count_b >= threshold && count_c >= threshold) begin
                                        // Found valid correlation
                                        best_found <= 1'b1;
                                        best_a <= a;
                                        best_b <= b;
                                        best_c <= c;
                                        best_n <= n;
                                        best_m <= m;
                                        best_i <= i;  // Use position i for earliest
                                    end
                                    // Reset for next combination
                                    search_step <= 2'd0;
                                    count_a <= 8'd0;
                                    count_c <= 8'd0;
                                    // Move to next (a,n,b,m,c) combination
                                    m <= m + 6'd1;
                                    if (m > 6'd63) begin
                                        m <= 6'd1;
                                        n <= n + 6'd1;
                                        if (n > 6'd63) begin
                                            n <= 6'd1;
                                            c <= c + 4'd1;
                                            if (c > 4'd9) begin
                                                c <= 4'd0;
                                                b <= b + 4'd1;
                                                if (b > 4'd9) begin
                                                    b <= 4'd0;
                                                    a <= a + 4'd1;
                                                    if (a > 4'd9) begin
                                                        // All combinations exhausted
                                                        best_found <= 1'b1;
                                                        best_a <= 4'd0;
                                                        best_b <= 4'd0;
                                                        best_c <= 4'd0;
                                                        best_n <= 6'd0;
                                                        best_m <= 6'd0;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    searching <= 1'b0;
                    done <= 1'b1;
                    if (best_found && best_a != 4'd0) begin
                        found <= 1'b1;
                        a_out <= best_a;
                        b_out <= best_b;
                        c_out <= best_c;
                        n_out <= best_n;
                        m_out <= best_m;
                    end else begin
                        found <= 1'b0;
                        a_out <= 4'd0;
                        b_out <= 4'd0;
                        c_out <= 4'd0;
                        n_out <= 6'd0;
                        m_out <= 6'd0;
                    end
                end

                default: begin
                    done <= 1'b0;
                    found <= 1'b0;
                end
            endcase
        end
    end

endmodule