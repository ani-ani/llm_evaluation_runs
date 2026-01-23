module largest_subset(
    input clk,
    input rst_n,
    input start,
    input [2:0] count,
    input [7:0] data_in,
    input [2:0] addr,
    input write_en,
    output reg [3:0] result,
    output reg done,
    output reg valid
);

    // Internal array to store numbers
    reg [7:0] arr [0:7];
    
    // DP array to store subset sizes
    reg [3:0] dp [0:7];
    
    // State machine states
    typedef enum logic [3:0] {
        IDLE,
        LOAD,
        OUTER_INIT,
        OUTER_LOOP,
        INNER_INIT,
        INNER_LOOP,
        COMPARE,
        UPDATE,
        FIND_MAX,
        DONE
    } state_t;
    
    state_t state, next_state;
    
    // Counters for loops
    reg [2:0] i, j;
    reg [3:0] max_val;
    
    // Flags
    reg divisible;
    
    // Divider implementation (combinational)
    function automatic logic [7:0] divide(input [7:0] dividend, input [7:0] divisor);
        if (divisor == 0) begin
            return 0;
        end else begin
            logic [7:0] quotient = 0;
            logic [7:0] remainder = dividend;
            for (int k = 7; k >= 0; k--) begin
                if ((remainder >> k) >= divisor) begin
                    remainder = remainder - (divisor << k);
                    quotient[k] = 1;
                end
            end
            return quotient;
        end
    endfunction
    
    // Check divisibility
    function automatic logic is_divisible(input [7:0] a, input [7:0] b);
        if (b == 0) return 0;
        logic [7:0] quotient = divide(a, b);
        logic [7:0] product = quotient * b;
        return (product == a);
    endfunction
    
    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = OUTER_INIT;
            end
            OUTER_INIT: begin
                next_state = OUTER_LOOP;
            end
            OUTER_LOOP: begin
                if (i == 0) next_state = FIND_MAX;
                else next_state = INNER_INIT;
            end
            INNER_INIT: begin
                next_state = INNER_LOOP;
            end
            INNER_LOOP: begin
                if (j == count) next_state = OUTER_LOOP;
                else next_state = COMPARE;
            end
            COMPARE: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                next_state = INNER_LOOP;
            end
            FIND_MAX: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Data loading
    always @(posedge clk) begin
        if (write_en && addr < 8) begin
            arr[addr] <= data_in;
        end
    end
    
    // State actions
    always @(posedge clk) begin
        if (!rst_n) begin
            done <= 0;
            valid <= 0;
            result <= 0;
        end else begin
            case (state)
                LOAD: begin
                    // Initialize DP array
                    for (int k = 0; k < 8; k++) begin
                        dp[k] <= 1;
                    end
                end
                OUTER_INIT: begin
                    i <= count - 1;
                end
                OUTER_LOOP: begin
                    i <= i - 1;
                end
                INNER_INIT: begin
                    j <= i + 1;
                end
                INNER_LOOP: begin
                    j <= j + 1;
                end
                COMPARE: begin
                    divisible = is_divisible(arr[i], arr[j]) || is_divisible(arr[j], arr[i]);
                end
                UPDATE: begin
                    if (divisible && dp[j] + 1 > dp[i]) begin
                        dp[i] <= dp[j] + 1;
                    end
                end
                FIND_MAX: begin
                    max_val = 0;
                    for (int k = 0; k < count; k++) begin
                        if (dp[k] > max_val) begin
                            max_val = dp[k];
                        end
                    end
                    result <= max_val;
                end
                DONE: begin
                    done <= 1;
                    valid <= 1;
                end
                default: ;
            endcase
        end
    end
    
    // Reset done and valid when start is asserted
    always @(posedge clk) begin
        if (start) begin
            done <= 0;
            valid <= 0;
        end
    end

endmodule