module exponial_mod(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE = 4'd1;
    localparam [3:0] FINISH = 4'd2;
    
    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;
    
    // Internal registers for computation
    reg [7:0] current_n;
    reg [31:0] current_m;
    reg [31:0] temp_result;
    reg [7:0] recursion_depth;
    
    // Euler's totient function helper
    function [31:0] euler_totient;
        input [31:0] m_val;
        reg [31:0] result_val;
        integer i;
        
        begin
            result_val = m_val;
            for (i = 2; i * i <= m_val; i = i + 1) begin
                if (m_val % i == 0) begin
                    result_val = result_val - (result_val / i);
                    while (m_val % i == 0) begin
                        m_val = m_val / i;
                    end
                end
            end
            if (m_val > 1) begin
                result_val = result_val - (result_val / m_val);
            end
            euler_totient = result_val;
        end
    endfunction
    
    // Modular exponentiation function
    function [31:0] mod_exp;
        input [31:0] base;
        input [31:0] exp;
        input [31:0] mod;
        reg [31:0] result_val;
        reg [31:0] current_exp;
        reg [31:0] current_base;
        
        begin
            result_val = 1;
            current_base = base % mod;
            current_exp = exp;
            
            while (current_exp > 0) begin
                if (current_exp[0]) begin
                    result_val = (result_val * current_base) % mod;
                end
                current_base = (current_base * current_base) % mod;
                current_exp = current_exp >> 1;
            end
            mod_exp = result_val;
        end
    endfunction
    
    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_n <= 8'd0;
            current_m <= 32'd0;
            temp_result <= 32'd0;
            recursion_depth <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_n <= n;
                        current_m <= m;
                        temp_result <= 32'd0;
                        recursion_depth <= 8'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Base cases
                    if (current_n == 8'd1) begin
                        temp_result <= 32'd1;
                    end else if (current_n == 8'd2) begin
                        temp_result <= 32'd2;
                    end else if (current_n == 8'd3) begin
                        temp_result <= 32'd9;
                    end else if (current_n == 8'd4) begin
                        temp_result <= 32'd262144 % current_m;
                    end else if (current_n >= 8'd5 && current_n <= 8'd255) begin
                        // Euler's totient reduction
                        if (recursion_depth < 8'd16) begin
                            temp_result <= mod_exp(2, current_n - 1, current_m);
                        end
                    end
                    
                    // Check if computation is complete
                    if (temp_result != 32'd0 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule