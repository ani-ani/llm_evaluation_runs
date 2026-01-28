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
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [3:0] i;  // Current index (1-based)
    reg [31:0] fact;  // Factorial accumulator
    reg [31:0] sum;   // Sum accumulator
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            fact <= 32'd0;
            sum <= 32'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            
            // Initialize result array
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                result[j] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 4'd1;
                        fact <= 32'd1;  // factorial(1) = 1
                        sum <= 32'd1;   // sum(1) = 1
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Store result based on parity
                    if (i[0] == 1'b0) begin  // Even index (i is odd: 1,3,5...)
                        result[i-1] <= (fact > 16'd65535) ? 16'd65535 : fact[15:0];
                    end else begin  // Odd index (i is even: 2,4,6...)
                        result[i-1] <= sum[15:0];
                    end
                    
                    // Update accumulators for next iteration
                    if (i < n) begin
                        i <= i + 4'd1;
                        fact <= fact * i;  // factorial(i+1) = factorial(i) * (i+1)
                        sum <= sum + i;    // sum(1..i+1) = sum(1..i) + (i+1)
                    end else begin
                        state <= DONE_STATE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule