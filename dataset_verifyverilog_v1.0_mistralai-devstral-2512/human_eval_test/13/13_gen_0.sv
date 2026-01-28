module GCDCalculator(
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [15:0] current_a;
    reg [15:0] current_b;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd32;
    
    // Remainder computation using subtraction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_a <= 16'd0;
            current_b <= 16'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_a <= a;
                        current_b <= b;
                        cycle_count <= 5'd0;
                        if (b == 16'd0) begin
                            result <= a;
                            state <= DONE_STATE;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Compute remainder using subtraction
                    if (current_b != 16'd0) begin
                        reg [15:0] remainder;
                        reg [15:0] temp_a;
                        reg [15:0] temp_b;
                        integer i;
                        
                        temp_a = current_a;
                        temp_b = current_b;
                        remainder = temp_a;
                        
                        // Subtraction loop (bounded by 16 bits)
                        for (i = 0; i < 16; i = i + 1) begin
                            if (remainder >= temp_b) begin
                                remainder = remainder - temp_b;
                            end
                        end
                        
                        current_a <= current_b;
                        current_b <= remainder;
                        cycle_count <= cycle_count + 5'd1;
                        
                        if (current_b == 16'd0 || cycle_count >= MAX_CYCLES) begin
                            result <= current_a;
                            state <= DONE_STATE;
                        end
                    end else begin
                        result <= current_a;
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