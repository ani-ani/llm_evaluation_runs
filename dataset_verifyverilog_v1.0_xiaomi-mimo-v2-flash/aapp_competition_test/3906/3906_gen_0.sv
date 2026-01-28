module fib_grid_calc (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [15:0] m,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;  // 10^9+7
    localparam [31:0] MOD_TIMES_2 = 32'd2000000014;  // 2*MOD
    
    // States
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CALC_FIB_N   = 3'd1;
    localparam [2:0] CALC_FIB_M   = 3'd2;
    localparam [2:0] COMBINE      = 3'd3;
    localparam [2:0] OUTPUT       = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] target_idx;  // Target Fibonacci index to calculate
    reg [15:0] current_idx; // Current iteration index
    reg [31:0] fib_prev;    // F_{i-1}
    reg [31:0] fib_curr;    // F_i
    reg [31:0] fib_result;  // Store result for n or m
    reg [31:0] temp_result; // Intermediate calculation
    reg [15:0] max_val;     // max(n, m) for loop bound
    reg [1:0] phase;        // Track which fib calculation we're on (0=n, 1=m)
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            target_idx <= 16'd0;
            current_idx <= 16'd0;
            fib_prev <= 32'd0;
            fib_curr <= 32'd0;
            fib_result <= 32'd0;
            temp_result <= 32'd0;
            max_val <= 16'd0;
            phase <= 2'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for first calculation (Fib(n-1))
                        if (n == 16'd1) begin
                            // Special case: Fib(0) = 1
                            fib_result <= 32'd1;
                            target_idx <= 16'd0;
                        end else begin
                            // Start at index 2: Fib(1)=2, Fib(2)=3
                            target_idx <= n - 16'd1;  // n-1
                            fib_prev <= 32'd1;  // F_0 = 1
                            fib_curr <= 32'd2;  // F_1 = 2
                            current_idx <= 16'd2;
                        end
                        phase <= 2'd0;  // First phase (n)
                        max_val <= (n > m) ? n : m;
                    end
                end
                
                CALC_FIB_N: begin
                    if (current_idx <= target_idx) begin
                        // Compute next Fibonacci
                        fib_curr <= (fib_prev + fib_curr) % MOD;
                        fib_prev <= fib_curr;
                        current_idx <= current_idx + 16'd1;
                    end else begin
                        // Done calculating Fib(n-1)
                        fib_result <= fib_curr;
                        // Prepare for Fib(m-1)
                        if (m == 16'd1) begin
                            target_idx <= 16'd0;
                        end else begin
                            target_idx <= m - 16'd1;  // m-1
                            fib_prev <= 32'd1;  // F_0 = 1
                            fib_curr <= 32'd2;  // F_1 = 2
                            current_idx <= 16'd2;
                        end
                        phase <= 2'd1;  // Second phase (m)
                    end
                end
                
                CALC_FIB_M: begin
                    if (m == 16'd1) begin
                        // Special case: Fib(0) = 1
                        temp_result <= fib_result + 32'd1;  // fib_result + 1
                    end else if (current_idx <= target_idx) begin
                        // Compute next Fibonacci
                        fib_curr <= (fib_prev + fib_curr) % MOD;
                        fib_prev <= fib_curr;
                        current_idx <= current_idx + 16'd1;
                    end else begin
                        // Done calculating Fib(m-1)
                        // Combine: fib_result (F_n-1) + fib_curr (F_m-1) - 1
                        temp_result <= (fib_result + fib_curr + MOD - 32'd1) % MOD;
                    end
                end
                
                COMBINE: begin
                    // Multiply by 2: result = temp * 2 mod MOD
                    if (temp_result < (MOD >> 1)) begin
                        result <= (temp_result << 1);  // *2 when small
                    end else begin
                        result <= (temp_result << 1) - MOD;  // *2 - MOD
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n == 16'd1 && m == 16'd1) begin
                        next_state = COMBINE;  // Skip fib calc, combine directly
                    end else if (n == 16'd1) begin
                        next_state = CALC_FIB_M;  // Only need m
                    end else begin
                        next_state = CALC_FIB_N;
                    end
                end
            end
            
            CALC_FIB_N: begin
                if (current_idx > target_idx) begin
                    if (m == 16'd1) begin
                        next_state = COMBINE;  // m=1, skip m calculation
                    end else begin
                        next_state = CALC_FIB_M;
                    end
                end
            end
            
            CALC_FIB_M: begin
                if (m == 16'd1 || current_idx > target_idx) begin
                    next_state = COMBINE;
                end
            end
            
            COMBINE: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule