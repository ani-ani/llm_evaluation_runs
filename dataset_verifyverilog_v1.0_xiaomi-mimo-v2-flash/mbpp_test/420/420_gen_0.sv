module cube_sum_even(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] i;              // Iteration counter (1 to n)
    reg [31:0] sum;           // Accumulated sum
    reg [7:0] cycle_count;    // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational signals for computation
    wire [7:0] even_val;      // 2*i
    wire [31:0] cube_val;     // (2*i)^3
    wire [31:0] new_sum;      // sum + cube_val

    // Combinational logic for cube calculation
    // (2*i) can be 2 to 30, cube fits in 32 bits
    assign even_val = {i, 1'b0};  // i*2 (i[2:0] shifted left)
    assign cube_val = (even_val * even_val) * even_val;  // (2i)^3
    assign new_sum = sum + cube_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 4'd0;
            sum <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;              // Clear done signal
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    sum <= 32'd0;
                    
                    if (start) begin
                        if (n == 4'd0) begin
                            // n=0 case, result is 0
                            result <= 32'd0;
                            state <= FINISH;
                        end else begin
                            // Start computation
                            i <= 4'd1;         // Start from i=1
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute cube and accumulate
                    sum <= new_sum;
                    i <= i + 4'd1;
                    
                    // Check completion conditions
                    if (i >= n) begin
                        // Finished all iterations
                        result <= new_sum;
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout (should not happen for n≤15)
                        result <= sum;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;              // Assert done
                    state <= IDLE;             // Return to idle
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule