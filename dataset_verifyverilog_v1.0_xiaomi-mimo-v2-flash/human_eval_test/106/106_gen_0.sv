module factorial_sum_array (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] i;              // Current index (1-based)
    reg [31:0] fact;          // Factorial accumulator
    reg [31:0] sum;           // Sum accumulator
    reg [31:0] cycle_count;   // Cycle counter for timeout
    
    // Max cycles to prevent timeout (N=16, max ~16 cycles + overhead)
    localparam [31:0] MAX_CYCLES = 32'd256;
    
    // Wires for calculations
    wire [31:0] next_fact;
    wire [31:0] next_sum;
    wire [31:0] fact_clamped;
    
    // Calculate next factorial (fact * i)
    assign next_fact = (i > 32'd0) ? (fact * i) : 32'd1;
    
    // Calculate next sum (sum + i)
    assign next_sum = sum + i;
    
    // Clamp factorial to 16-bit max (65535)
    assign fact_clamped = (next_fact > 32'd65535) ? 32'd65535 : next_fact;
    
    // FSM and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            i <= 4'd0;
            fact <= 32'd0;
            sum <= 32'd0;
            cycle_count <= 32'd0;
            done <= 1'b0;
            // Reset all result array elements
            result[0] <= 16'd0;
            result[1] <= 16'd0;
            result[2] <= 16'd0;
            result[3] <= 16'd0;
            result[4] <= 16'd0;
            result[5] <= 16'd0;
            result[6] <= 16'd0;
            result[7] <= 16'd0;
            result[8] <= 16'd0;
            result[9] <= 16'd0;
            result[10] <= 16'd0;
            result[11] <= 16'd0;
            result[12] <= 16'd0;
            result[13] <= 16'd0;
            result[14] <= 16'd0;
            result[15] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    i <= 4'd0;
                    fact <= 32'd1;   // Initialize for i=1
                    sum <= 32'd0;
                    
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 32'd1;
                    
                    // Increment i (current iteration number)
                    i <= i + 4'd1;
                    
                    // Update accumulators for NEXT cycle
                    fact <= fact_clamped;
                    sum <= next_sum;
                    
                    // Check if we should store to result array
                    // i is now the current index (1-based)
                    // Store to result[i-1] which is 0-based
                    if (i <= n) begin
                        // i is 1-based, store to result[i-1]
                        if (i[0] == 1'b0) begin
                            // i is even, store factorial
                            // fact_clamped is the factorial for this i
                            result[i-4'd1] <= (fact_clamped > 32'd65535) ? 16'd65535 : fact_clamped[15:0];
                        end else begin
                            // i is odd, store sum
                            result[i-4'd1] <= next_sum[15:0];
                        end
                    end
                    
                    // Check completion condition
                    if (i >= n || cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule