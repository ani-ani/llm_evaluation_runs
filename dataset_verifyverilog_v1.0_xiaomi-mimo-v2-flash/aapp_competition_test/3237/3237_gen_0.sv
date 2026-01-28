module find_min_cost_server (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] factor_str [0:15], // Fixed array of 16 bytes
    input wire [3:0] str_len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] PARSE         = 3'd1;
    localparam [2:0] COMPUTE_K     = 3'd2;
    localparam [2:0] DIV_ITERATE   = 3'd3;
    localparam [2:0] FINISH        = 3'd4;
    localparam [2:0] ERROR         = 3'd5;

    // Registers and variables
    reg [2:0] state, next_state;
    reg [3:0] idx;          // Index for factor string
    reg [31:0] K;           // Computed K value
    reg [31:0] temp_factor; // Current parsed factor
    reg [15:0] digit_count; // Counter for digits in current factor
    reg [31:0] i;           // Iterator for divisors
    reg [31:0] min_cost;
    reg [31:0] cost;
    reg [31:0] temp_K;      // Used for modulo check
    reg modulo_done;
    reg [7:0] cycle_count;  // Safety timeout
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper logic for ASCII conversion and modulo
    wire [7:0] char = factor_str[idx];
    wire [3:0] digit_val = (char >= 8'h30 && char <= 8'h39) ? (char - 8'h30) : 4'd10; // 10 is error

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            K <= 32'd1;
            i <= 32'd1;
            min_cost <= 32'hFFFF_FFFF;
            idx <= 4'd0;
            temp_factor <= 32'd0;
            cycle_count <= 8'd0;
            modulo_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        idx <= 4'd0;
                        K <= 32'd1;
                        temp_factor <= 32'd0;
                        min_cost <= 32'hFFFF_FFFF;
                        cycle_count <= 8'd0;
                    end
                end

                PARSE: begin
                    if (idx < str_len) begin
                        if (digit_val < 4'd10) begin
                            // Accumulate factor: temp_factor = temp_factor * 10 + digit
                            if (temp_factor > 32'd429496729) begin // Prevent overflow before multiplication
                                state <= ERROR;
                            end else begin
                                temp_factor <= (temp_factor << 3) + (temp_factor << 1) + digit_val; // *10 + digit
                                idx <= idx + 4'd1;
                                state <= PARSE;
                            end
                        end else begin
                            // Non-digit found (separator), compute K = K * temp_factor
                            if (temp_factor > 32'd0) begin
                                K <= K * temp_factor;
                                temp_factor <= 32'd0;
                                state <= COMPUTE_K;
                            end else begin
                                // Skip separator if temp_factor is 0 (consecutive separators)
                                idx <= idx + 4'd1;
                            end
                        end
                    end else begin
                        // End of string, process last factor
                        if (temp_factor > 32'd0) begin
                            K <= K * temp_factor;
                        end
                        state <= DIV_ITERATE;
                        i <= 32'd1;
                        cycle_count <= 8'd0;
                    end
                end

                COMPUTE_K: begin
                    // Transition back to parsing after processing a factor
                    idx <= idx + 4'd1;
                    state <= PARSE;
                end

                DIV_ITERATE: begin
                    // Check if i * i > K (i.e., i > sqrt(K)) or timeout
                    // To avoid sqrt logic, we check if i*i > K. Since i and K are 32-bit,
                    // i*i is 64-bit. We perform check carefully.
                    if ((i > 32'd65535) || (i * i > K) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end else begin
                        // Check divisibility: K % i == 0
                        // We implement a simple subtraction loop or reuse logic.
                        // Since this is hardware, we do one step per cycle.
                        // However, to be efficient, we will assume we check divisibility
                        // in one cycle (combinational logic for small i, or sequential).
                        // For sequential, we need a state SUBTRACT.
                        // Let's optimize: we can check K % i == 0 using combinational logic
                        // if we assume synthesis handles it, OR we do a small sequential loop.
                        // Given constraints, we'll use combinational check for simplicity,
                        // but to ensure timing, let's do a sequential remainder check.
                        
                        // Setup for remainder calculation
                        temp_K <= K;
                        modulo_done <= 1'b0;
                        
                        // Start remainder subtraction loop
                        // Since i is small (grows slowly), subtracting i from K repeatedly is slow.
                        // Better approach: Use built-in % if possible, but standard Verilog synthesis
                        // might not like large % in logic. 
                        // Let's try a direct check: `if (K % i == 0)`
                        // Most tools optimize this.
                        if ((K % i) == 32'd0) begin
                            // It divides. Calculate cost = i + K/i
                            cost <= i + (K / i);
                            // We update min_cost next cycle to avoid combinational loop
                            // Actually, we can do it directly.
                            if ((i + (K / i)) < min_cost) begin
                                min_cost <= i + (K / i);
                            end
                        end
                        
                        i <= i + 32'd1;
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                FINISH: begin
                    result <= min_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end

                ERROR: begin
                    // In case of overflow or bad input
                    result <= 32'hDEAD_BEEF;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule