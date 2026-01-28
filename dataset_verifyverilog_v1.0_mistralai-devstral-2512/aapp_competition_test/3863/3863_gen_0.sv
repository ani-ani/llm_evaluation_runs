module CyclicPalindromeCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] N_in,
    input wire [31:0] K_in,
    input wire [31:0] MOD_in,
    output reg [63:0] result,
    output reg done,
    output reg valid
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0] MAX_DIVISORS = 8'd256;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_DIVISORS = 3'd1;
    localparam [2:0] COMPUTE_F = 3'd2;
    localparam [2:0] CLEAN_F = 3'd3;
    localparam [2:0] SUM = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // State machine
    reg [2:0] state, next_state;

    // Counters
    reg [7:0] divisor_count;
    reg [7:0] current_divisor_idx;
    reg [7:0] inner_loop_idx;
    reg [7:0] exponentiation_cycle;

    // Storage
    reg [15:0] divisors [0:255];
    reg [31:0] f_values [0:255];
    reg [31:0] f_clean_values [0:255];

    // Intermediate values
    reg [31:0] N_reg, K_reg, MOD_reg;
    reg [31:0] current_divisor;
    reg [31:0] current_f_value;
    reg [31:0] current_f_clean;
    reg [31:0] temp_product;
    reg [31:0] exponent_result;
    reg [31:0] sum_result;

    // Exponentiation variables
    reg [31:0] base, exponent, mod;
    reg [31:0] exp_result;
    reg [31:0] exp_temp;

    // Control signals
    reg compute_f_done;
    reg clean_f_done;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            divisor_count <= 8'd0;
            current_divisor_idx <= 8'd0;
            inner_loop_idx <= 8'd0;
            exponentiation_cycle <= 8'd0;
            
            for (i = 0; i < 256; i = i + 1) begin
                divisors[i] <= 16'd0;
                f_values[i] <= 32'd0;
                f_clean_values[i] <= 32'd0;
            end
            
            N_reg <= 32'd0;
            K_reg <= 32'd0;
            MOD_reg <= 32'd0;
            current_divisor <= 32'd0;
            current_f_value <= 32'd0;
            current_f_clean <= 32'd0;
            temp_product <= 32'd0;
            exponent_result <= 32'd0;
            sum_result <= 32'd0;
            
            base <= 32'd0;
            exponent <= 32'd0;
            mod <= 32'd0;
            exp_result <= 32'd0;
            exp_temp <= 32'd0;
            
            compute_f_done <= 1'b0;
            clean_f_done <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 64'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIND_DIVISORS;
                    N_reg = N_in;
                    K_reg = K_in;
                    MOD_reg = MOD_in;
                    divisor_count = 8'd0;
                    current_divisor_idx = 8'd0;
                    done = 1'b0;
                    valid = 1'b0;
                end
            end
            
            FIND_DIVISORS: begin
                if (divisor_count < MAX_DIVISORS && current_divisor_idx < 256) begin
                    // Find divisors of N_reg
                    if (divisors[current_divisor_idx] == 16'd0) begin
                        // Find next divisor
                        reg [31:0] d;
                        reg [31:0] sqrt_N;
                        reg [31:0] temp_d;
                        
                        sqrt_N = 32'd0;
                        for (i = 0; i < 32; i = i + 1) begin
                            if ((sqrt_N + (1'b1 << i)) * (sqrt_N + (1'b1 << i)) <= N_reg) begin
                                sqrt_N = sqrt_N + (1'b1 << i);
                            end
                        end
                        
                        if (current_divisor_idx == 8'd0) begin
                            divisors[0] = 16'd1;
                            divisor_count = 8'd1;
                        end else begin
                            d = divisors[current_divisor_idx - 1] + 16'd1;
                            while (d <= sqrt_N) begin
                                if (N_reg % d == 32'd0) begin
                                    divisors[current_divisor_idx] = d;
                                    divisor_count = divisor_count + 8'd1;
                                    break;
                                end
                                d = d + 16'd1;
                            end
                        end
                    end
                    
                    if (divisors[current_divisor_idx] != 16'd0) begin
                        current_divisor_idx = current_divisor_idx + 8'd1;
                    end
                    
                    if (current_divisor_idx >= divisor_count) begin
                        next_state = COMPUTE_F;
                        current_divisor_idx = 8'd0;
                    end
                end else begin
                    next_state = COMPUTE_F;
                    current_divisor_idx = 8'd0;
                end
            end
            
            COMPUTE_F: begin
                if (current_divisor_idx < divisor_count) begin
                    current_divisor = divisors[current_divisor_idx];
                    
                    // Compute ceil(d/2)
                    reg [31:0] ceil_d_2;
                    ceil_d_2 = (current_divisor + 32'd1) >> 1;
                    
                    // Compute K^ceil(d/2) mod MOD
                    base = K_reg;
                    exponent = ceil_d_2;
                    mod = MOD_reg;
                    
                    // Fast modular exponentiation
                    exp_result = 32'd1;
                    exp_temp = base;
                    exponentiation_cycle = 8'd0;
                    
                    while (exponent > 32'd0) begin
                        if (exponent[0]) begin
                            exp_result = (exp_result * exp_temp) % mod;
                        end
                        exp_temp = (exp_temp * exp_temp) % mod;
                        exponent = exponent >> 1;
                        exponentiation_cycle = exponentiation_cycle + 8'd1;
                    end
                    
                    if (exponent[0]) begin
                        exp_result = (exp_result * exp_temp) % mod;
                    end
                    
                    f_values[current_divisor_idx] = exp_result;
                    current_divisor_idx = current_divisor_idx + 8'd1;
                end else begin
                    compute_f_done = 1'b1;
                    next_state = CLEAN_F;
                    current_divisor_idx = 8'd0;
                end
            end
            
            CLEAN_F: begin
                if (current_divisor_idx < divisor_count) begin
                    current_f_clean = f_values[current_divisor_idx];
                    
                    // Subtract sum of f_clean(e) for all e|d, e<d
                    inner_loop_idx = 8'd0;
                    while (inner_loop_idx < current_divisor_idx) begin
                        if (divisors[current_divisor_idx] % divisors[inner_loop_idx] == 32'd0) begin
                            current_f_clean = (current_f_clean - f_clean_values[inner_loop_idx] + MOD_reg) % MOD_reg;
                        end
                        inner_loop_idx = inner_loop_idx + 8'd1;
                    end
                    
                    f_clean_values[current_divisor_idx] = current_f_clean;
                    current_divisor_idx = current_divisor_idx + 8'd1;
                end else begin
                    clean_f_done = 1'b1;
                    next_state = SUM;
                    current_divisor_idx = 8'd0;
                    sum_result = 32'd0;
                end
            end
            
            SUM: begin
                if (current_divisor_idx < divisor_count) begin
                    current_divisor = divisors[current_divisor_idx];
                    current_f_clean = f_clean_values[current_divisor_idx];
                    
                    // Compute contribution
                    if (current_divisor[0]) begin
                        // Odd: d * f_clean(d)
                        temp_product = (current_divisor * current_f_clean) % MOD_reg;
                    end else begin
                        // Even: (d/2) * f_clean(d)
                        temp_product = ((current_divisor >> 1) * current_f_clean) % MOD_reg;
                    end
                    
                    sum_result = (sum_result + temp_product) % MOD_reg;
                    current_divisor_idx = current_divisor_idx + 8'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                result = sum_result;
                done = 1'b1;
                valid = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule