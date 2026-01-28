module geometric_sum (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] sum,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // State and control registers
    reg [1:0] state, next_state;
    reg [3:0] iteration_count;  // Iterations completed (0 to n-1)
    reg [15:0] accumulator;     // Running sum in Q8.8 format
    reg [15:0] term;            // Current term (256 >> iteration_count)
    reg start_delayed;          // To detect start pulse

    // Constants
    localparam [15:0] ONE_Q8_8 = 16'd256;  // 1.0 in Q8.8 format

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum <= 16'd0;
            done <= 1'b0;
            iteration_count <= 4'd0;
            accumulator <= 16'd0;
            term <= 16'd0;
            start_delayed <= 1'b0;
        end else begin
            start_delayed <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iteration_count <= 4'd0;
                    accumulator <= 16'd0;
                    term <= 16'd0;
                    
                    // Detect start pulse
                    if (start && !start_delayed) begin
                        if (n == 4'd0) begin
                            // n=0 case: sum is 0
                            state <= DONE;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Calculate current term: 256 >> iteration_count
                    // Right shift arithmetic for positive values
                    term <= ONE_Q8_8 >> iteration_count;
                    
                    // Add term to accumulator
                    accumulator <= accumulator + (ONE_Q8_8 >> iteration_count);
                    
                    // Increment iteration count
                    iteration_count <= iteration_count + 4'd1;
                    
                    // Check if done computing (completed n iterations)
                    // iteration_count will be n after this cycle
                    if (iteration_count == n - 4'd1) begin
                        // Complete the sum and move to DONE
                        // The final term was just added above
                        sum <= accumulator + (ONE_Q8_8 >> iteration_count);
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule