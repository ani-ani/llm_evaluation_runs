module sum_fourth_powers(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [19:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] i;
    reg [3:0] n_reg;
    reg [31:0] accumulator;
    reg [15:0] odd;
    reg [15:0] odd_sq;
    reg [31:0] odd_quad;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            n_reg <= 4'd0;
            accumulator <= 32'd0;
            odd <= 16'd0;
            odd_sq <= 16'd0;
            odd_quad <= 32'd0;
            result <= 20'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n;
                        i <= 4'd1;
                        accumulator <= 32'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate odd number: 2*i - 1
                    odd <= (i << 1) - 16'd1;
                    
                    // Compute odd^2
                    odd_sq <= odd * odd;
                    
                    // Compute odd^4
                    odd_quad <= odd_sq * odd_sq;
                    
                    // Accumulate
                    accumulator <= accumulator + odd_quad;
                    
                    // Increment counter
                    i <= i + 4'd1;
                    
                    // Check if done
                    if (i > n_reg || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= accumulator[19:0];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule