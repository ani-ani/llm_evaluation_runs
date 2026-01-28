module LargestDivisibleSubset(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr [0:15],
    input wire [3:0] length,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // DP array storage
    reg [4:0] dp [0:15];
    reg [3:0] i_reg, j_reg;
    reg [4:0] max_size;
    reg [4:0] current_max;

    // Divisibility check signals
    reg divisible;
    reg [15:0] a_val, b_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP array
            for (integer k = 0; k < 16; k = k + 1) begin
                dp[k] <= 5'd0;
            end
            
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            max_size <= 5'd0;
            current_max <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        max_size <= 5'd0;
                        
                        // Initialize DP array
                        for (integer k = 0; k < 16; k = k + 1) begin
                            dp[k] <= 5'd1;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current elements
                    a_val = arr[i_reg];
                    b_val = arr[j_reg];
                    
                    // Check divisibility
                    if (b_val != 16'd0 && (a_val % b_val == 16'd0 || b_val % a_val == 16'd0)) begin
                        divisible = 1'b1;
                    end else begin
                        divisible = 1'b0;
                    end
                    
                    // Update current_max if divisible
                    if (divisible && j_reg > i_reg) begin
                        if (dp[j_reg] > current_max) begin
                            current_max = dp[j_reg];
                        end
                    end
                    
                    // Increment j_reg
                    j_reg <= j_reg + 4'd1;
                    
                    // Check if j_reg reached length
                    if (j_reg == length) begin
                        // Update dp[i_reg]
                        dp[i_reg] <= current_max + 5'd1;
                        
                        // Update max_size
                        if (dp[i_reg] > max_size) begin
                            max_size = dp[i_reg];
                        end
                        
                        // Reset for next i
                        current_max <= 5'd0;
                        j_reg <= 4'd0;
                        
                        // Increment i_reg
                        i_reg <= i_reg + 4'd1;
                        
                        // Check if i_reg reached length
                        if (i_reg == length) begin
                            state <= FINISH;
                        end
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= max_size;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule