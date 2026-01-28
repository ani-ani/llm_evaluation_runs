module check_reverse_condition (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg result,
    output reg valid
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] INIT      = 4'd1;
    localparam [3:0] DIV_LOOP  = 4'd2;
    localparam [3:0] CALC_REV  = 4'd3;
    localparam [3:0] CHECK     = 4'd4;
    localparam [3:0] DONE      = 4'd5;
    
    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] temp_reg;           // Current value for digit extraction
    reg [7:0] rev_reg;            // Accumulated reverse value
    reg [7:0] quotient;           // For division by 10
    reg [3:0] remainder;          // For modulus by 10
    reg [3:0] cycle_count;        // Safety counter
    
    // Wires for division by 10
    wire [7:0] div_result;
    wire [3:0] mod_result;
    
    // Division by 10 using multiplication and shifting
    // n / 10 = (n * 51) >> 9  (51/512 ≈ 0.0996)
    wire [14:0] mult_result;
    assign mult_result = temp_reg * 8'd51;
    assign div_result = mult_result[14:7];  // Shift right 7 bits (effectively 7)
    
    // For better accuracy with 8-bit numbers:
    // We'll use a simple subtraction counter approach
    // Actually, for 8-bit, we can use lookup or simple logic
    // Let's implement using a counter method for division by 10
    
    // Better: Use combinational logic for division/modulo by 10
    reg [7:0] div_out;
    reg [3:0] mod_out;
    
    always @(*) begin
        // Division by 10 for 8-bit numbers
        // n = 10*q + r, where r < 10
        div_out = 0;
        mod_out = temp_reg[3:0];  // Start with lower nibble
        
        // Convert BCD or use lookup
        // For simplicity and correctness, use subtraction method
        // This will be implemented in state machine
    end
    
    // Actually, let's implement a combinational divider by 10
    // Using the fact that for n < 256, n/10 and n%10 can be computed
    // via multiplication by 205 and shifting right 11 bits
    
    wire [15:0] temp_mult;
    assign temp_mult = temp_reg * 16'd205;  // 205/2048 ≈ 0.1
    
    // For division: shift right 11 bits
    wire [4:0] div_temp;
    assign div_temp = temp_mult[15:11];  // Rough division by 10
    
    // For better accuracy with small numbers, use direct comparison
    // Let's implement a proper divider in the state machine
    
    // Revised approach: use combinational divider with subtraction
    // This is synthesizable and avoids division operator
    reg [7:0] div_result_comb;
    reg [3:0] mod_result_comb;
    reg div_done;
    
    always @(*) begin
        div_result_comb = 8'd0;
        mod_result_comb = 4'd0;
        
        // Compute n / 10 and n % 10
        // For n in 0..255
        // We can use a priority encoder style logic
        // Or simple subtraction loop (combinational)
        
        // Combinational subtraction-based division
        div_result_comb = 8'd0;
        mod_result_comb = temp_reg[3:0];  // Initial remainder guess
        
        // This is a simple approximation - better to do in state machine
        // For synthesis, we'll do iterative subtraction in state machine
    end
    
    // Let's implement the division properly in the state machine
    // We'll use a counter to perform repeated subtraction
    reg [7:0] div_temp_reg;
    reg [3:0] div_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            valid <= 1'b0;
            temp_reg <= 8'd0;
            rev_reg <= 8'd0;
            quotient <= 8'd0;
            remainder <= 4'd0;
            cycle_count <= 4'd0;
            div_temp_reg <= 8'd0;
            div_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize reverse calculation
                    temp_reg <= n;
                    rev_reg <= 8'd0;
                    quotient <= 8'd0;
                    remainder <= 4'd0;
                    div_counter <= 4'd0;
                    div_temp_reg <= n;
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (n == 8'd0) begin
                        // Special case: n = 0, reverse is 0
                        rev_reg <= 8'd0;
                        state <= CHECK;
                    end else begin
                        state <= DIV_LOOP;
                    end
                end
                
                DIV_LOOP: begin
                    // Perform division by 10 using repeated subtraction
                    // For 8-bit numbers, max 25 loops needed, but we limit
                    if (div_temp_reg >= 8'd10) begin
                        div_temp_reg <= div_temp_reg - 8'd10;
                        quotient <= quotient + 8'd1;
                        div_counter <= div_counter + 4'd1;
                    end else begin
                        remainder <= div_temp_reg[3:0];
                        state <= CALC_REV;
                    end
                    
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count > 4'd14) begin
                        state <= DONE;
                    end
                end
                
                CALC_REV: begin
                    // rev = rev * 10 + remainder
                    rev_reg <= rev_reg * 8'd10 + remainder;
                    temp_reg <= quotient;
                    quotient <= 8'd0;
                    div_temp_reg <= quotient;
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if quotient is 0 (done extracting digits)
                    if (quotient == 8'd0) begin
                        state <= CHECK;
                    end else begin
                        state <= DIV_LOOP;
                    end
                end
                
                CHECK: begin
                    // Check condition: 2 * rev == n + 1
                    if ((rev_reg << 1) == (n + 8'd1)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= DONE;
                    cycle_count <= cycle_count + 4'd1;
                end
                
                DONE: begin
                    valid <= 1'b1;
                    state <= IDLE;
                    cycle_count <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule