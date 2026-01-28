module MemoryGameSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] LOAD      = 2'd1;
    localparam [1:0] COMPUTE   = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    // Fixed-point constants (Q16.16 format)
    localparam [31:0] ONE      = 32'h00010000;  // 1.0 in Q16.16
    localparam [31:0] TWO      = 32'h00020000;  // 2.0
    localparam [31:0] THREE    = 32'h00030000;  // 3.0
    localparam [31:0] ZERO     = 32'h00000000;  // 0.0

    // FSM registers
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Computation registers
    reg [3:0] counter;          // Current N being computed
    reg [3:0] target_n;         // Target N from input
    reg [31:0] e_prev1;         // E(n-1) in Q16.16
    reg [31:0] e_prev2;         // E(n-2) in Q16.16
    reg [31:0] e_curr;          // E(n) in Q16.16
    
    // Computation signals
    wire [63:0] term1;          // E(n-1) in Q32.32
    wire [63:0] term2;          // 2.0 * E(n-2) in Q32.32
    wire [63:0] sum;            // term1 + term2 in Q32.32
    wire [63:0] divided;        // sum / 3.0 in Q32.32
    wire [31:0] result_temp;    // 1.0 + divided[31:0] in Q16.16
    
    // Control registers
    reg [7:0] cycle_count;      // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Fixed-point multiplication and division
    // term1 = e_prev1 (no shift needed)
    assign term1 = {32'h00000000, e_prev1};
    
    // term2 = 2.0 * e_prev2 = e_prev2 << 1
    assign term2 = {e_prev2[30:0], 16'h0000};
    
    // sum = term1 + term2
    assign sum = term1 + term2;
    
    // divided = sum / 3.0 (preserve fractional bits)
    assign divided = sum / THREE;
    
    // result_temp = 1.0 + divided (lower 32 bits of result)
    assign result_temp = ONE + divided[31:0];

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? LOAD : IDLE;
            LOAD: next_state = COMPUTE;
            COMPUTE: next_state = (counter >= target_n) ? FINISH : COMPUTE;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter <= 4'd0;
            target_n <= 4'd0;
            e_prev1 <= 32'd0;
            e_prev2 <= 32'd0;
            e_curr <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            done <= 1'b0;  // Default: done is 0
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    counter <= 4'd0;
                    cycle_count <= 8'd0;
                    // Wait for start
                end
                
                LOAD: begin
                    target_n <= n;
                    // Initialize base cases
                    if (n == 4'd0) begin
                        e_prev1 <= 32'd0;  // E(0) = 0
                        e_prev2 <= 32'd0;  // E(-1) unused but zero
                        e_curr <= 32'd0;
                    end else if (n == 4'd1) begin
                        e_prev1 <= 32'd0;  // E(0) = 0
                        e_prev2 <= 32'd0;  // Placeholder
                        e_curr <= ONE;     // E(1) = 1.0
                    end else begin
                        // For N >= 2, start with E(1) = 1.0, E(0) = 0.0
                        e_prev1 <= ONE;     // E(1)
                        e_prev2 <= 32'd0;   // E(0)
                        e_curr <= 32'd0;
                    end
                    counter <= 4'd2;  // Start computing from E(2)
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute E(counter) = 1.0 + (E(counter-1) + 2.0*E(counter-2)) / 3.0
                    e_curr <= result_temp;
                    
                    // Update history
                    e_prev2 <= e_prev1;   // E(n-2) = E(n-1)
                    e_prev1 <= result_temp;  // E(n-1) = E(n)
                    
                    // Increment counter
                    counter <= counter + 4'd1;
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Output is the last computed value for target_n
                    // For n=0: result should be 0 (already set in LOAD)
                    // For n=1: result is e_curr (set in LOAD)
                    // For n>=2: result is e_curr (computed in COMPUTE)
                    result <= (target_n == 4'd1) ? e_curr : e_curr;
                    // Note: For n=0 and n=1, result is already correct
                    // For n>=2, e_curr contains E(n) at the end of COMPUTE
                    
                    // For n=1, e_curr was set in LOAD, so we need to pass it
                    // Actually, let's fix the logic:
                    // In LOAD for n=1, e_curr = ONE
                    // In COMPUTE for n=1 (if target_n=1), we don't enter COMPUTE
                    // So result is correct
                    // For n>=2, e_curr is updated in COMPUTE
                    
                    // Special handling for n=1 to avoid confusion
                    if (target_n == 4'd1) begin
                        result <= e_curr;  // This is ONE
                    end else if (target_n == 4'd0) begin
                        result <= 32'd0;   // Explicitly set for n=0
                    end
                    // For n>=2, e_curr already has the correct value
                    
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule