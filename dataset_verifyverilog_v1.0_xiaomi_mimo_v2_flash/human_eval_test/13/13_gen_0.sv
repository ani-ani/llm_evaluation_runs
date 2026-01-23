module gcd_calculator (
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] reg_a;
    reg [15:0] reg_b;
    reg [15:0] reg_temp;
    reg [3:0] cycle_count;  // Max 16 iterations for 16-bit numbers
    reg [3:0] sub_count;    // Counter for subtraction-based modulo
    localparam [3:0] MAX_CYCLES = 4'd15;
    
    // Combinational logic for next state and outputs
    always @(*) begin
        // Default values
        next_state = state;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Check if computation is complete
                if (reg_b == 16'd0) begin
                    next_state = DONE_STATE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    // Safety timeout to prevent infinite loops
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            reg_a <= 16'd0;
            reg_b <= 16'd0;
            reg_temp <= 16'd0;
            cycle_count <= 4'd0;
            sub_count <= 4'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;  // Clear done except when explicitly set
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Latch inputs
                        if (b == 16'd0) begin
                            // Edge case: b is 0, result is a immediately
                            result <= a;
                            reg_a <= a;
                            reg_b <= 16'd0;
                        end else begin
                            reg_a <= a;
                            reg_b <= b;
                        end
                        cycle_count <= 4'd0;
                        sub_count <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    if (reg_b != 16'd0) begin
                        // Perform modulo using subtraction-based approach
                        if (reg_a >= reg_b) begin
                            reg_a <= reg_a - reg_b;
                            sub_count <= sub_count + 4'd1;
                        end else begin
                            // Subtraction complete, swap values
                            reg_temp <= reg_b;      // New b = old a % old b = reg_a (since reg_a < reg_b)
                            reg_b <= reg_a;         // New a = old b = reg_b
                            reg_a <= reg_temp;      // Temporarily store new a
                            sub_count <= 4'd0;      // Reset sub counter for next iteration
                            cycle_count <= cycle_count + 4'd1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    result <= reg_a;  // Final GCD value
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    reg_a <= 16'd0;
                    reg_b <= 16'd0;
                    reg_temp <= 16'd0;
                    cycle_count <= 4'd0;
                    sub_count <= 4'd0;
                end
            endcase
        end
    end
endmodule