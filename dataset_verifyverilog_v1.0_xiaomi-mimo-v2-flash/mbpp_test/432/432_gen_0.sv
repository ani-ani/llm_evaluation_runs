module trapezium_median(
    input wire clk,
    input wire rst_n,
    input wire [7:0] base1,
    input wire [7:0] base2,
    input wire [7:0] height,  // Not used, kept for interface consistency
    input wire start,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [8:0] sum_temp;  // 9-bit to hold sum of two 8-bit numbers (max 510)
    reg start_prev;      // For edge detection

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            sum_temp <= 9'd0;
            start_prev <= 1'b0;
        end else begin
            start_prev <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;  // Clear done when idle
                    
                    // Detect rising edge of start
                    if (start && !start_prev) begin
                        state <= COMPUTE;
                        // Stage 1: Add bases (combinational in pipeline)
                        sum_temp <= base1 + base2;
                    end
                end
                
                COMPUTE: begin
                    // Stage 2: Shift right by 1 (division by 2)
                    result <= sum_temp[8:1];  // Take bits 8:1 (divides by 2)
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;  // Assert done for one cycle
                    state <= IDLE;  // Return to idle
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule