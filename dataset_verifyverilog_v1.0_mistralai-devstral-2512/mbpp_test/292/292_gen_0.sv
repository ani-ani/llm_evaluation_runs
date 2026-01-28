module Divider(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [15:0] m,
    output reg [15:0] q,
    output reg [15:0] r,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH  = 3'd3;

    reg [2:0] state, next_state;
    reg [15:0] remainder_reg;
    reg [15:0] quotient_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES - 1)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            remainder_reg <= 16'd0;
            quotient_reg <= 16'd0;
            cycle_count <= 4'd0;
            q <= 16'd0;
            r <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                INIT: begin
                    // Initialize registers
                    remainder_reg <= n;
                    quotient_reg <= 16'd0;
                    cycle_count <= 4'd0;
                    
                    // Handle division by zero
                    if (m == 16'd0) begin
                        quotient_reg <= 16'd0;
                        remainder_reg <= 16'd0;
                        next_state = FINISH;
                    end
                end
                
                COMPUTE: begin
                    // Shift-subtract algorithm
                    remainder_reg <= remainder_reg << 1;
                    remainder_reg[0] <= quotient_reg[15];
                    quotient_reg <= quotient_reg << 1;
                    
                    // Subtract if remainder >= m
                    if (remainder_reg >= m) begin
                        remainder_reg <= remainder_reg - m;
                        quotient_reg[0] <= 1'b1;
                    end
                    
                    cycle_count <= cycle_count + 4'd1;
                end
                
                FINISH: begin
                    q <= quotient_reg;
                    r <= remainder_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule