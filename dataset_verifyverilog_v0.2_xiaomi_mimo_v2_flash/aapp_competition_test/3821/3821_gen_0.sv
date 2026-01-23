module optimal_probability(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [7:0] p_in,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INPUT = 3'b001;
    localparam PROCESS = 3'b010;
    localparam FINALIZE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [3:0] count, next_count; // Counter for 8 inputs (max 8)
    
    // Internal registers for probabilities (Q16.16)
    // prod = product of (1-p)
    // sum = cumulative probability
    // best = maximum probability found so far
    reg [31:0] prod, next_prod;
    reg [31:0] sum, next_sum;
    reg [31:0] best, next_best;
    
    // Temporary multiplication results
    wire [63:0] sum_mul_1_p;
    wire [63:0] prod_mul_1_p;
    wire [63:0] prod_mul_p;
    wire [63:0] temp_sum;
    
    // Helper wires for Q8.8 to Q16.16 conversion and arithmetic
    wire [31:0] p_fixed;      // p_in converted to Q16.16
    wire [31:0] p_1_minus;    // (1-p) in Q16.16
    wire [31:0] p_fixed_ext;  // p_in zero-extended for multiplication logic if needed
    
    // Convert p_in (Q8.8) to Q16.16: shift left by 8
    assign p_fixed = {p_in, 16'd0};
    
    // Calculate (1-p) in Q16.16: 1.0 in Q16.16 is 32'h00010000
    assign p_1_minus = 32'h00010000 - p_fixed;
    
    // Multiplication operations
    // sum * (1-p)
    assign sum_mul_1_p = sum * p_1_minus;
    // prod * (1-p)
    assign prod_mul_1_p = prod * p_1_minus;
    // prod * p
    assign prod_mul_p = prod * p_fixed;
    
    // new_sum = sum*(1-p) + prod*p
    // We need to shift results back to Q16.16 (div by 2^16)
    assign temp_sum = (sum_mul_1_p >> 16) + (prod_mul_p >> 16);
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INPUT;
            end
            INPUT: begin
                // Fixed 8 cycles for maximum inputs
                if (count >= 4'd8) next_state = PROCESS;
            end
            PROCESS: begin
                // Processing takes 1 cycle (calculations are combinational)
                next_state = FINALIZE;
            end
            FINALIZE: begin
                // One more cycle to latch final max
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE; // Wait for start to go low
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(*) begin
        // Default assignments
        next_prod = prod;
        next_sum = sum;
        next_best = best;
        next_count = count;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_prod = 32'h00010000; // Initialize to 1.0 (Q16.16)
                    next_sum = 32'd0;
                    next_best = 32'd0;
                    next_count = 4'd0;
                end
            end
            
            INPUT: begin
                if (count < 4'd8) begin
                    // Update rule: new_sum = sum * (1-p) + prod * p
                    // new_prod = prod * (1-p)
                    
                    // perform calculations
                    next_sum = temp_sum[31:0]; // Take lower 32 bits of Q16.16 result
                    next_prod = (prod_mul_1_p >> 16); // Shift back to Q16.16
                    
                    // Check if current calculated sum is greater than best
                    if (temp_sum[31:0] > best) begin
                        next_best = temp_sum[31:0];
                    end
                    
                    next_count = count + 1'b1;
                end
            end
            
            PROCESS: begin
                // Just a staging state
                next_prod = prod;
                next_sum = sum;
                next_best = best;
            end
            
            FINALIZE: begin
                // Ensure final best is captured (compare one last time)
                // In this sequential loop, INPUT captures all values. 
                // We just latch best to result register.
                next_best = best;
            end
            
            DONE: begin
                // Hold values
            end
            
            default: begin
                next_prod = prod;
                next_sum = sum;
                next_best = best;
                next_count = count;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            prod <= 32'd0;
            sum <= 32'd0;
            best <= 32'd0;
            count <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            prod <= next_prod;
            sum <= next_sum;
            best <= next_best;
            count <= next_count;
            
            if (next_state == FINALIZE) begin
                // Latch result when transitioning to DONE
                result <= next_best;
            end
            
            if (next_state == DONE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule
