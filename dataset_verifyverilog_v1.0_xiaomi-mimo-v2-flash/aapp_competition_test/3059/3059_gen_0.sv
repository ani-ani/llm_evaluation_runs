module speedrun_optimal_time (
    input clk,
    input rst_n,
    input start,
    input [5:0] m_in,
    input [12:0] n_in,
    input [12:0] r_in,
    input [12:0] t_in [0:49],
    input [31:0] p_in [0:49],
    input [10:0] d_in [0:49],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] CALC_T  = 3'd3;
    localparam [2:0] RESULT  = 3'd4;
    localparam [2:0] FINISH  = 3'd5;

    // Fixed-point constants (Q16.16)
    localparam [31:0] ONE = 32'h00010000;  // 1.0

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] m_reg;
    reg [12:0] n_reg;
    reg [12:0] t_reg [0:49];
    reg [31:0] p_reg [0:49];
    reg [10:0] d_reg [0:49];
    reg [31:0] E_reg [0:50];  // E[0..50], E[50] is base case
    reg [5:0] i;  // Current trick index
    
    // Intermediate computation registers
    reg [31:0] T_cont_num;  // numerator for T_cont = (remaining + E[i+1])
    reg [31:0] T_cont_den;  // denominator = p[i]
    reg [63:0] T_cont_mult; // multiplication result
    reg [31:0] T_cont_div;  // division result
    reg [12:0] remaining;
    reg [31:0] T_reset;
    reg [31:0] E_next;      // E[i+1]
    reg [31:0] E_current;   // E[i]
    
    // Division state
    reg [31:0] div_a;
    reg [31:0] div_b;
    reg div_start;
    reg div_busy;
    reg [31:0] div_result;
    reg [1:0] div_state;
    localparam [1:0] DIV_IDLE = 2'd0;
    localparam [1:0] DIV_CALC = 2'd1;
    localparam [1:0] DIV_DONE = 2'd2;
    
    // Control signals
    reg busy;
    reg calc_done;
    
    // Helper: Integer to fixed-point (16-bit int to Q16.16)
    function automatic [31:0] int_to_fixed;
        input [15:0] int_val;
        begin
            int_to_fixed = {int_val, 16'd0};
        end
    endfunction
    
    // Helper: Fixed-point multiplication
    function automatic [31:0] fixed_mult;
        input [31:0] a;
        input [31:0] b;
        wire signed [63:0] temp;
        begin
            temp = $signed(a) * $signed(b);
            // Q16.16 * Q16.16 = Q32.32, take middle 32 bits (Q16.16)
            fixed_mult = temp[47:16];
        end
    endfunction
    
    // Helper: Fixed-point addition
    function automatic [31:0] fixed_add;
        input [31:0] a;
        input [31:0] b;
        begin
            fixed_add = a + b;
        end
    endfunction
    
    // Helper: Fixed-point comparison
    function automatic [0:0] fixed_le;
        input [31:0] a;
        input [31:0] b;
        begin
            fixed_le = ($signed(a) <= $signed(b));
        end
    endfunction

    // Division module: a / b where both are Q16.16, result Q16.16
    // Uses: (a << 16) / b
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_state <= DIV_IDLE;
            div_busy <= 1'b0;
            div_result <= 32'd0;
        end else begin
            case (div_state)
                DIV_IDLE: begin
                    if (div_start) begin
                        div_busy <= 1'b1;
                        div_state <= DIV_CALC;
                    end
                end
                DIV_CALC: begin
                    // a / b where a and b are Q16.16
                    // Need to compute (a << 16) / b
                    // If b is 0, return max
                    if (div_b == 32'd0) begin
                        div_result <= 32'h7FFFFFFF;  // Max positive
                        div_state <= DIV_DONE;
                    end else begin
                        // Use shift-based division for simplicity
                        // (a << 16) gives Q32.16, divide by Q16.16 gives Q16.16
                        // Use 64-bit intermediate
                        reg [63:0] numerator;
                        reg [31:0] quotient;
                        reg [31:0] remainder;
                        integer k;
                        
                        numerator = {div_a, 16'd0};  // Shift left by 16
                        quotient = 32'd0;
                        remainder = 32'd0;
                        
                        for (k = 31; k >= 0; k = k - 1) begin
                            remainder = remainder << 1;
                            remainder[0] = numerator[k+32];  // Take next bit
                            if (remainder >= div_b) begin
                                remainder = remainder - div_b;
                                quotient[k] = 1'b1;
                            end
                        end
                        
                        div_result <= quotient;
                        div_state <= DIV_DONE;
                    end
                end
                DIV_DONE: begin
                    div_busy <= 1'b0;
                    div_state <= DIV_IDLE;
                end
            endcase
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            i <= 6'd0;
            calc_done <= 1'b0;
            div_start <= 1'b0;
            // Initialize arrays
            begin
                integer j;
                for (j = 0; j < 51; j = j + 1) begin
                    E_reg[j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        busy <= 1'b1;
                        i <= 6'd0;
                    end
                end
                
                LOAD: begin
                    // Load inputs into registers
                    if (i < m_in) begin
                        m_reg <= m_in;
                        n_reg <= n_in;
                        t_reg[i] <= t_in[i];
                        p_reg[i] <= p_in[i];
                        d_reg[i] <= d_in[i];
                        i <= i + 6'd1;
                    end else begin
                        // Initialize base case E[m] = n (fixed-point)
                        E_reg[m_in] <= {n_in, 16'd0};
                        i <= m_in;  // Start from m-1
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (i > 6'd0) begin
                        i <= i - 6'd1;  // Process i-1, so decrement first
                        state <= CALC_T;
                        
                        // Setup computation for index (i-1)
                        // remaining = n - t[i-1]
                        remaining <= n_reg - t_reg[i - 6'd1];
                        E_next <= E_reg[i];  // E[i]
                        
                        // T_cont = (remaining + E[i+1]) / p[i]
                        // numerator = remaining (fixed) + E[i]
                        T_cont_num <= {remaining, 16'd0} + E_reg[i];
                        T_cont_den <= p_reg[i - 6'd1];
                        
                        // T_reset = d[i] + t[i]
                        T_reset <= {19'd0, d_reg[i - 6'd1]} + {19'd0, t_reg[i - 6'd1]};
                    end else begin
                        state <= RESULT;
                    end
                end
                
                CALC_T: begin
                    // Calculate T_cont using division
                    if (!div_busy) begin
                        div_a <= T_cont_num;
                        div_b <= T_cont_den;
                        div_start <= 1'b1;
                    end else begin
                        div_start <= 1'b0;
                    end
                    
                    if (div_state == DIV_DONE) begin
                        T_cont_div <= div_result;
                        state <= RESULT;
                    end
                end
                
                RESULT: begin
                    // Choose minimal
                    if (T_cont_div != 32'h7FFFFFFF && fixed_le(T_cont_div, T_reset)) begin
                        E_reg[i] <= T_cont_div;
                    end else begin
                        E_reg[i] <= T_reset;
                    end
                    
                    // Continue or finish
                    if (i == 6'd0) begin
                        state <= FINISH;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    result <= E_reg[0];
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule