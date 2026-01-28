module CombinatorialCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] n_high,
    input wire [19:0] n_low,
    input wire [19:0] t_high,
    input wire [19:0] t_low,
    output reg [31:0] result_high,
    output reg [31:0] result_low,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_T = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Input and intermediate registers
    reg [39:0] n_reg;
    reg [39:0] t_reg;
    reg [39:0] n_plus_2;
    reg [5:0] k;
    reg is_power_of_two;
    reg [63:0] result;

    // Binomial coefficient calculator state
    reg [5:0] c_n;
    reg [5:0] c_k;
    reg [63:0] c_result;
    reg [5:0] c_i;
    reg [5:0] c_j;
    reg [63:0] c_temp;
    reg [5:0] c_max_k;

    // Digit DP state
    reg [5:0] bit_pos;
    reg [5:0] ones_count;
    reg [63:0] dp_result;

    // Check if t is power of two
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            n_reg <= 40'd0;
            t_reg <= 40'd0;
            n_plus_2 <= 40'd0;
            k <= 6'd0;
            is_power_of_two <= 1'b0;
            result <= 64'd0;
            result_high <= 32'd0;
            result_low <= 32'd0;
            done <= 1'b0;
            
            // Binomial calculator reset
            c_n <= 6'd0;
            c_k <= 6'd0;
            c_result <= 64'd0;
            c_i <= 6'd0;
            c_j <= 6'd0;
            c_temp <= 64'd0;
            c_max_k <= 6'd0;
            
            // Digit DP reset
            bit_pos <= 6'd0;
            ones_count <= 6'd0;
            dp_result <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load inputs
                        n_reg <= {n_high, n_low};
                        t_reg <= {t_high, t_low};
                        state <= CHECK_T;
                    end
                end

                CHECK_T: begin
                    // Check if t is power of two
                    is_power_of_two <= 1'b1;
                    for (integer i = 0; i < 40; i = i + 1) begin
                        if (t_reg[i] && (i != 0 || t_reg[0] != 1'b1)) begin
                            is_power_of_two <= 1'b0;
                        end
                    end
                    
                    if (!is_power_of_two) begin
                        result <= 64'd0;
                        state <= FINISH;
                    end else begin
                        // Compute k = log2(t)
                        k <= 6'd0;
                        for (integer i = 39; i >= 0; i = i - 1) begin
                            if (t_reg[i]) begin
                                k <= i;
                                break;
                            end
                        end
                        
                        // Compute n_plus_2 = n + 2
                        n_plus_2 <= n_reg + 40'd2;
                        
                        // Initialize digit DP
                        bit_pos <= 39;
                        ones_count <= 6'd0;
                        dp_result <= 64'd0;
                        
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Digit DP loop
                        if (bit_pos >= 0) begin
                            if (n_plus_2[bit_pos]) begin
                                // Current bit is 1
                                // Option 1: choose 0 for current bit
                                // Need (k - ones_count) ones in remaining (bit_pos) bits
                                if (k >= ones_count) begin
                                    c_n <= bit_pos;
                                    c_k <= k - ones_count;
                                    c_result <= 64'd0;
                                    c_i <= 6'd0;
                                    c_j <= 6'd0;
                                    c_temp <= 64'd0;
                                    c_max_k <= c_k;
                                    state <= COMPUTE;
                                end
                                
                                // Increment ones_count
                                ones_count <= ones_count + 6'd1;
                            end
                            
                            bit_pos <= bit_pos - 6'd1;
                        end else begin
                            // Finished bit iteration
                            result <= dp_result;
                            
                            // Special case: t == 1 (k == 0)
                            if (k == 6'd0) begin
                                result <= result - 64'd1;
                            end
                            
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result_high <= result[63:32];
                    result_low <= result[31:0];
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Binomial coefficient calculator (sequential)
    always @(posedge clk) begin
        if (state == COMPUTE && c_n > 0) begin
            if (c_i == 0) begin
                c_result <= 64'd1;
                c_i <= c_n;
                c_j <= 6'd0;
            end else if (c_j <= c_max_k) begin
                if (c_j == 0) begin
                    c_temp <= c_result;
                    c_j <= c_j + 6'd1;
                end else begin
                    c_result <= c_temp * (c_i - c_j + 6'd1) / c_j;
                    c_j <= c_j + 6'd1;
                end
            end else begin
                dp_result <= dp_result + c_result;
                c_n <= 6'd0;
            end
        end
    end

endmodule