module GCD(
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [4:0] cycle_counter;  // 5-bit counter for max 32 cycles
    reg [15:0] reg_a;
    reg [15:0] reg_b;
    reg computing_remainder;
    reg [15:0] remainder;
    reg [15:0] remainder_a;
    reg [15:0] remainder_b;
    
    // Constants
    localparam [4:0] MAX_CYCLES = 5'd32;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_counter <= 5'd0;
            reg_a <= 16'd0;
            reg_b <= 16'd0;
            computing_remainder <= 1'b0;
            remainder <= 16'd0;
            remainder_a <= 16'd0;
            remainder_b <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 5'd0;
                    computing_remainder <= 1'b0;
                    if (start) begin
                        // Load inputs
                        reg_a <= a;
                        reg_b <= b;
                        // Check for immediate completion
                        if (b == 16'd0) begin
                            result <= a;
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    done <= 1'b0;
                    
                    if (computing_remainder) begin
                        // Continue remainder calculation (subtract b from a)
                        if (remainder_a >= remainder_b && remainder_a != 16'd0 && remainder_b != 16'd0) begin
                            remainder_a <= remainder_a - remainder_b;
                        end else begin
                            // Remainder calculation complete
                            remainder <= remainder_a;
                            computing_remainder <= 1'b0;
                        end
                    end else begin
                        // Normal computation cycle
                        if (reg_b == 16'd0) begin
                            // Algorithm complete
                            result <= reg_a;
                            done <= 1'b1;
                            state <= DONE;
                        end else if (cycle_counter >= MAX_CYCLES) begin
                            // Timeout protection
                            result <= reg_a;
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Compute a % b using subtraction
                            // Start remainder calculation
                            remainder_a <= reg_a;
                            remainder_b <= reg_b;
                            computing_remainder <= 1'b1;
                            // State remains in COMPUTE
                            
                            // We need to update after remainder is computed
                            // This requires an extra cycle
                        end
                    end
                    
                    // Handle update after remainder computed
                    if (!computing_remainder && cycle_counter < MAX_CYCLES && reg_b != 16'd0) begin
                        // Update a and b for next iteration
                        // Move this to a separate condition
                    end
                end
                
                DONE: begin
                    // Return to idle
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Counter increment logic
            if (state == COMPUTE && !computing_remainder && reg_b != 16'd0 && cycle_counter < MAX_CYCLES) begin
                cycle_counter <= cycle_counter + 5'd1;
            end
            
            // Update registers after remainder is computed
            if (state == COMPUTE && computing_remainder && (remainder_a < remainder_b || remainder_a == 16'd0 || remainder_b == 16'd0)) begin
                // Just finished computing remainder
                // Update for next iteration
                reg_a <= reg_b;
                if (remainder_a == 16'd0) begin
                    reg_b <= 16'd0;
                end else begin
                    reg_b <= remainder_a;
                end
            end
        end
    end

endmodule