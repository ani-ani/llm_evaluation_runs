module FunctionCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] p_in,
    input wire [7:0] k_in,
    output reg [29:0] result,
    output reg done,
    output reg valid
);

    // Constants
    localparam [29:0] MOD = 30'd1000000007;
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ORDER = 3'd1;
    localparam [2:0] COMPUTE_POWER = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] p_reg, k_reg;
    reg [7:0] order_count;
    reg [31:0] current_n;
    reg [31:0] exponent_reg;
    reg [31:0] base_reg;
    reg [31:0] power_result;
    reg [7:0] cycle_counter;
    reg [7:0] max_cycles;
    
    // Modular multiplication function
    function [31:0] mod_mult;
        input [31:0] a, b, mod_val;
        reg [31:0] result;
        integer i;
        begin
            result = 32'd0;
            for (i = 0; i < 32; i = i + 1) begin
                if (a[i])
                    result = (result + b) % mod_val;
                b = b << 1;
                if (b >= mod_val)
                    b = b - mod_val;
            end
            mod_mult = result;
        end
    endfunction
    
    // Modular exponentiation function
    function [31:0] mod_exp;
        input [31:0] base, exp, mod_val;
        reg [31:0] result;
        reg [31:0] current_base;
        reg [31:0] current_exp;
        begin
            result = 32'd1;
            current_base = base % mod_val;
            current_exp = exp;
            while (current_exp > 0) begin
                if (current_exp[0])
                    result = mod_mult(result, current_base, mod_val);
                current_base = mod_mult(current_base, current_base, mod_val);
                current_exp = current_exp >> 1;
            end
            mod_exp = result;
        end
    endfunction
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 30'd0;
            done <= 1'b0;
            valid <= 1'b0;
            p_reg <= 8'd0;
            k_reg <= 8'd0;
            order_count <= 8'd0;
            current_n <= 32'd0;
            exponent_reg <= 32'd0;
            base_reg <= 32'd0;
            power_result <= 32'd0;
            cycle_counter <= 8'd0;
            max_cycles <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        p_reg <= p_in;
                        k_reg <= k_in;
                        next_state <= COMPUTE_ORDER;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE_ORDER: begin
                    // Special cases for k=0 and k=1
                    if (k_reg == 8'd0) begin
                        exponent_reg <= {24'd0, p_reg} - 32'd1; // p-1
                        next_state <= COMPUTE_POWER;
                    end else if (k_reg == 8'd1) begin
                        exponent_reg <= {24'd0, p_reg}; // p
                        next_state <= COMPUTE_POWER;
                    end else begin
                        // Find order o for k>1
                        if (cycle_counter == 8'd0) begin
                            current_n <= {24'd0, k_reg};
                            order_count <= 8'd1;
                            max_cycles <= p_reg - 8'd1;
                        end else begin
                            if (current_n == 32'd1) begin
                                exponent_reg <= ({24'd0, p_reg} - 32'd1) / {24'd0, order_count};
                                next_state <= COMPUTE_POWER;
                            end else begin
                                current_n <= mod_mult(current_n, {24'd0, k_reg}, {24'd0, p_reg});
                                order_count <= order_count + 8'd1;
                                if (cycle_counter >= max_cycles) begin
                                    // Safety: if order not found, use p-1
                                    exponent_reg <= {24'd0, p_reg} - 32'd1;
                                    next_state <= COMPUTE_POWER;
                                end
                            end
                        end
                        cycle_counter <= cycle_counter + 8'd1;
                    end
                end
                
                COMPUTE_POWER: begin
                    base_reg <= {24'd0, p_reg};
                    power_result <= mod_exp(base_reg, exponent_reg, MOD);
                    result <= power_result[29:0];
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end
    
    // Default assignments
    always @(*) begin
        next_state = state;
    end

endmodule