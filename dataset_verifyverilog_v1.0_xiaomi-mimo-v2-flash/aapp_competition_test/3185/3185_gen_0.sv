module inverse_factorial (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] x,
    output reg [7:0] n,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [63:0] accumulator;
    reg [7:0] i;
    reg [7:0] max_iterations;
    reg computation_complete;
    
    // Combinational signals
    wire accumulator_ge_x;
    assign accumulator_ge_x = (accumulator >= x);
    
    // State register and next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset: initialize all registers
            state <= IDLE;
            accumulator <= 64'd1;
            i <= 8'd2;
            n <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            max_iterations <= 8'd30;
            computation_complete <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear done and valid signals
                    done <= 1'b0;
                    valid <= 1'b0;
                    computation_complete <= 1'b0;
                    
                    if (start) begin
                        // Start new computation
                        // Check special cases
                        if (x == 64'd1) begin
                            // 1! = 1, n = 1
                            n <= 8'd1;
                            valid <= 1'b1;
                            state <= FINISH;
                        end else if (x == 64'd0) begin
                            // 0! = 1, but x=0 is invalid
                            // According to spec, input is x = n!
                            // So x should be >= 1
                            // Return 0 for invalid
                            n <= 8'd0;
                            valid <= 1'b0;
                            state <= FINISH;
                        end else begin
                            // Normal case: start from i=2, acc=1
                            accumulator <= 64'd1;
                            i <= 8'd2;
                            computation_complete <= 1'b0;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    valid <= 1'b0;
                    
                    // Multiply accumulator by i
                    // accumulator = accumulator * i
                    accumulator <= accumulator * i;
                    
                    // Check if we have overflowed the computation
                    // or completed the factorial
                    if (accumulator_ge_x) begin
                        // Found the answer: n = i - 1
                        // Since we just multiplied by i and now acc >= x,
                        // the factorial that equals x must be i-1
                        n <= i - 8'd1;
                        computation_complete <= 1'b1;
                        state <= FINISH;
                    end else if (i >= max_iterations) begin
                        // Safety check: reached max iterations
                        // Return 0 (invalid) or previous value
                        n <= 8'd0;
                        valid <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Continue computation
                        i <= i + 8'd1;
                        state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    // Set done and valid
                    done <= 1'b1;
                    // valid was already set in COMPUTE or IDLE
                    // Return to IDLE
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                    accumulator <= 64'd1;
                    i <= 8'd2;
                    n <= 8'd0;
                end
            endcase
        end
    end

endmodule