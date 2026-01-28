module CountFunctions (
    input clk,
    input rst_n,
    input start,
    input [7:0] p_in,
    input [7:0] k_in,
    output reg [29:0] result,
    output reg done,
    output reg valid
);

// Constants
localparam [29:0] MOD = 30'd1000000007;
localparam [7:0] MAX_P = 8'd255;

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CHECK_K = 3'd1;
localparam [2:0] COMPUTE_ORDER = 3'd2;
localparam [2:0] COMPUTE_EXP = 3'd3;
localparam [2:0] COMPUTE_POWER = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

// Internal registers
reg [2:0] state, next_state;
reg [7:0] p_reg;
reg [7:0] k_reg;
reg [7:0] o_reg;           // Order o
reg [7:0] temp_o;          // Temporary order counter
reg [7:0] temp_n;          // For order computation
reg [29:0] base;           // Base for exponentiation (p)
reg [29:0] exponent;       // Exponent
reg [29:0] pow_result;     // Power calculation result
reg [7:0] exp_counter;     // Exponentiation iteration counter
reg [29:0] temp_pow;       // Temporary for exponentiation
reg [7:0] mult_counter;    // Multiplication loop counter
reg [29:0] temp_mult;      // Temporary for multiplication

// Helper registers for specific cases
reg [7:0] case_selector;   // 0: k=0, 1: k=1, 2: k>1

// Combinational logic
always @(*) begin
    case (state)
        IDLE: next_state = start ? CHECK_K : IDLE;
        CHECK_K: begin
            if (k_reg == 8'd0 || k_reg == 8'd1 || p_reg <= 8'd2)
                next_state = COMPUTE_POWER;
            else
                next_state = COMPUTE_ORDER;
        end
        COMPUTE_ORDER: begin
            if (temp_n == 8'd1)
                next_state = COMPUTE_EXP;
            else
                next_state = COMPUTE_ORDER;
        end
        COMPUTE_EXP: next_state = COMPUTE_POWER;
        COMPUTE_POWER: begin
            if (mult_counter == 8'd0)
                next_state = DONE_STATE;
            else
                next_state = COMPUTE_POWER;
        end
        DONE_STATE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 30'd0;
        done <= 1'b0;
        valid <= 1'b0;
        p_reg <= 8'd0;
        k_reg <= 8'd0;
        o_reg <= 8'd0;
        temp_o <= 8'd0;
        temp_n <= 8'd0;
        base <= 30'd0;
        exponent <= 30'd0;
        pow_result <= 30'd0;
        exp_counter <= 8'd0;
        temp_pow <= 30'd0;
        mult_counter <= 8'd0;
        temp_mult <= 30'd0;
        case_selector <= 8'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    p_reg <= p_in;
                    k_reg <= k_in;
                    // Initialize for next state
                    result <= 30'd0;
                end
            end
            
            CHECK_K: begin
                // Determine which case we're in
                if (k_reg == 8'd0)
                    case_selector <= 8'd0;  // k=0
                else if (k_reg == 8'd1)
                    case_selector <= 8'd1;  // k=1
                else if (p_reg <= 8'd2)
                    case_selector <= 8'd1;  // Treat as k=1 for p=2
                else
                    case_selector <= 8'd2;  // k>1
                
                // Initialize order finding for k>1
                if (k_reg != 8'd0 && k_reg != 8'd1 && p_reg > 8'd2) begin
                    temp_o <= 8'd1;
                    temp_n <= k_reg % p_reg;
                end
            end
            
            COMPUTE_ORDER: begin
                // Find order of k mod p
                if (temp_n != 8'd1) begin
                    temp_o <= temp_o + 8'd1;
                    temp_n <= (temp_n * k_reg) % p_reg;
                end
            end
            
            COMPUTE_EXP: begin
                // Set up exponent based on case_selector
                o_reg <= temp_o;  // Store computed order
                if (case_selector == 8'd0) begin
                    // k=0: exponent = p-1
                    exponent <= p_reg - 8'd1;
                end else if (case_selector == 8'd1) begin
                    // k=1: exponent = p
                    exponent <= p_reg;
                end else begin
                    // k>1: exponent = (p-1)/o
                    exponent <= (p_reg - 8'd1) / temp_o;
                end
                base <= p_reg;  // Base is always p
            end
            
            COMPUTE_POWER: begin
                // Modular exponentiation: base^exponent mod MOD
                // Initialize on first entry
                if (exp_counter == 8'd0) begin
                    pow_result <= 30'd1;  // Start with result = 1
                    temp_pow <= base % MOD;  // Base mod MOD
                    exp_counter <= 8'd1;  // Start counting
                    mult_counter <= exponent;  // Loop count for binary exponent
                end else begin
                    // Binary exponentiation logic
                    // We'll do iterative exponentiation
                    // Check bit of exponent
                    if (mult_counter[0]) begin
                        // Multiply result by temp_pow
                        temp_mult <= pow_result;
                    end else begin
                        temp_mult <= 30'd1;
                    end
                    
                    // Square the base (temp_pow = temp_pow * temp_pow mod MOD)
                    if (exp_counter <= 8'd29) begin  // 30 bits max
                        temp_pow <= (temp_pow * temp_pow) % MOD;
                    end
                    
                    // Continue if more bits
                    if (exp_counter < 8'd30) begin
                        mult_counter <= mult_counter >> 1;
                        exp_counter <= exp_counter + 8'd1;
                    end else begin
                        // Complete
                        if (temp_mult != 30'd1) begin
                            pow_result <= (pow_result * temp_mult) % MOD;
                        end
                    end
                end
            end
            
            DONE_STATE: begin
                result <= pow_result;
                done <= 1'b1;
                valid <= 1'b1;
                // Reset counters for next operation
                exp_counter <= 8'd0;
                mult_counter <= 8'd0;
            end
        endcase
    end
end

endmodule