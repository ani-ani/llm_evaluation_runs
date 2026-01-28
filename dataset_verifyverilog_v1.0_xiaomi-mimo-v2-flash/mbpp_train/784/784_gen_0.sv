module mul_even_odd(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SCAN    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    // State register
    reg [1:0] state, next_state;
    
    // Internal registers
    reg [3:0] index;
    reg [7:0] first_even;
    reg [7:0] first_odd;
    reg [15:0] product;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    // Combinational: even/odd check
    wire is_even;
    assign is_even = (arr[index][0] == 1'b0);
    
    // Next state logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN;
            end
            
            SCAN: begin
                if (index >= len || cycle_count >= MAX_CYCLES)
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            first_even <= 8'hFF;
            first_odd <= 8'hFF;
            product <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    index <= 4'd0;
                    first_even <= 8'hFF;
                    first_odd <= 8'hFF;
                    product <= 16'd0;
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current element if within bounds
                    if (index < len && index < 8) begin
                        if (is_even && (first_even == 8'hFF)) begin
                            first_even <= arr[index];
                        end
                        if (!is_even && (first_odd == 8'hFF)) begin
                            first_odd <= arr[index];
                        end
                        index <= index + 4'd1;
                    end
                end
                
                COMPUTE: begin
                    // Compute product: first_even * first_odd
                    product <= first_even * first_odd;
                end
                
                FINISH: begin
                    result <= product;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    index <= 4'd0;
                    first_even <= 8'hFF;
                    first_odd <= 8'hFF;
                    product <= 16'd0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end
endmodule