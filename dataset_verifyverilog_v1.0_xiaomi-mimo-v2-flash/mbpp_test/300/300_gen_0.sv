module BinarySequenceCount (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_N   = 3'd1;
    localparam [2:0] INIT_VARS = 3'd2;
    localparam [2:0] COMPUTE_C = 3'd3;
    localparam [2:0] ACCUMULATE = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] result_reg;
    reg [15:0] C_current;      // C(n, r-1)
    reg [15:0] C_next;         // C(n, r)
    reg [15:0] C_squared;
    reg [3:0] r_counter;       // r from 1 to n
    reg [3:0] n_reg;
    reg start_delayed;         // To detect start pulse

    // Combinational signals
    reg [15:0] C_next_temp;
    reg [15:0] C_squared_temp;
    wire [15:0] C_next_mult;
    wire [15:0] C_next_div;
    wire [31:0] C_sq_temp;

    // Arithmetic calculations for C(n,r)
    // C(n,r) = C(n,r-1) * (n-r+1) / r
    // For n <= 4, values fit in 16 bits
    assign C_next_mult = C_current * (n_reg - r_counter + 4'd1);
    assign C_next_div = C_next_mult / r_counter;  // Exact integer division
    assign C_sq_temp = C_current * C_current;     // C(n,r-1)^2

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 16'd0;
            C_current <= 16'd0;
            C_next <= 16'd0;
            C_squared <= 16'd0;
            r_counter <= 4'd0;
            n_reg <= 4'd0;
            start_delayed <= 1'b0;
            done <= 1'b0;
            result <= 16'd0;
        end else begin
            // Register start pulse for edge detection
            start_delayed <= start;
            
            // Output reg (done is set in FINISH state)
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start && !start_delayed) begin
                        state <= CHECK_N;
                        n_reg <= n;
                    end
                    result_reg <= 16'd0;
                    C_current <= 16'd0;
                    r_counter <= 4'd0;
                end
                
                CHECK_N: begin
                    if (n_reg == 4'd0) begin
                        // n=0 case: result = 1.0 => 1*256 = 256
                        result_reg <= 16'd256;
                        state <= FINISH;
                    end else begin
                        state <= INIT_VARS;
                    end
                end
                
                INIT_VARS: begin
                    // Initialize for r=1: C(n,1) = n
                    C_current <= {12'd0, n_reg};
                    // Accumulate 1^2 = 1 for the base term (C(n,0)^2 = 1)
                    result_reg <= 16'd1 * 16'd256;  // 1.0 in Q8.8
                    r_counter <= 4'd1;
                    state <= COMPUTE_C;
                end
                
                COMPUTE_C: begin
                    // Calculate C(n, r) from C(n, r-1)
                    // C_current holds C(n, r-1)
                    // C_next holds C(n, r)
                    C_next <= C_next_div;
                    
                    if (r_counter < n_reg) begin
                        r_counter <= r_counter + 4'd1;
                        state <= ACCUMULATE;
                    end else begin
                        // Last iteration: r == n
                        // Need to accumulate C(n, n)^2 before finish
                        state <= ACCUMULATE;
                    end
                end
                
                ACCUMULATE: begin
                    // Add C(n, r-1)^2 to result
                    // C_current holds C(n, r-1) at this point
                    // The multiplication result is from previous clock
                    // Need to handle multiplication result properly
                    // Since C_current is valid from COMPUTE_C, we square it now
                    
                    // Accumulate C(n, r-1)^2 * 256
                    if (C_sq_temp[31:16] == 16'd0) begin
                        result_reg <= result_reg + (C_sq_temp[15:0] * 16'd256);
                    end
                    
                    // Move to next C
                    C_current <= C_next;
                    
                    if (r_counter > n_reg) begin
                        // Finished all iterations
                        state <= FINISH;
                    end else begin
                        state <= COMPUTE_C;
                    end
                end
                
                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule