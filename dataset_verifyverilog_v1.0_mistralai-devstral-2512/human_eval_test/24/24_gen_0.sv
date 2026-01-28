module LargestProperDivisor(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [15:0] counter;
    reg [15:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd65534;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 16'd0;
            temp_result <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        counter <= n - 16'd1;
                        temp_result <= 16'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if counter is a divisor
                    if (n % counter == 16'd0) begin
                        temp_result <= counter;
                        state <= FINISH;
                    end else if (counter == 16'd1) begin
                        // Reached 1, which is always a divisor
                        temp_result <= 16'd1;
                        state <= FINISH;
                    end else begin
                        counter <= counter - 16'd1;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Handle edge cases
                    if (n == 16'd0 || n == 16'd1) begin
                        result <= 16'd0;
                    end else begin
                        result <= temp_result;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule