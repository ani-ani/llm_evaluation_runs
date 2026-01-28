module mul_even_odd(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SCAN    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [7:0] first_even;
    reg [7:0] first_odd;
    reg [15:0] product;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SCAN: begin
                if (index == len - 1'b1) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = SCAN;
                end
            end
            
            COMPUTE: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            first_even <= 8'hFF;
            first_odd <= 8'hFF;
            product <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check current element
                    if (arr[index][0] == 1'b0 && first_even == 8'hFF) begin
                        first_even <= arr[index];
                    end
                    
                    if (arr[index][0] == 1'b1 && first_odd == 8'hFF) begin
                        first_odd <= arr[index];
                    end
                    
                    // Increment index
                    if (index < len - 1'b1) begin
                        index <= index + 4'd1;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate product
                    product <= first_even * first_odd;
                    result <= product;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    // Reset internal registers for next operation
                    index <= 4'd0;
                    first_even <= 8'hFF;
                    first_odd <= 8'hFF;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule