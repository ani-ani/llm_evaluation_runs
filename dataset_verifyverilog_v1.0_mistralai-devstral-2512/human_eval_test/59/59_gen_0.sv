module PrimeFactor(
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_SQRT = 3'd1;
    localparam [2:0] DIVIDE    = 3'd2;
    localparam [2:0] UPDATE    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] n_reg;
    reg [15:0] remaining;
    reg [7:0] candidate;
    reg [15:0] max_factor;
    reg [15:0] product;
    reg [15:0] remainder;
    reg divisible;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_SQRT;
                end
            end
            
            CHECK_SQRT: begin
                if (candidate * candidate > remaining || candidate >= 8'd255) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = DIVIDE;
                end
            end
            
            DIVIDE: begin
                next_state = UPDATE;
            end
            
            UPDATE: begin
                next_state = CHECK_SQRT;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_reg <= 16'd0;
            remaining <= 16'd0;
            candidate <= 8'd0;
            max_factor <= 16'd0;
            product <= 16'd0;
            remainder <= 16'd0;
            divisible <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n_in;
                        remaining <= n_in;
                        candidate <= 8'd3;
                        max_factor <= 16'd1;
                    end
                end
                
                CHECK_SQRT: begin
                    cycle_count <= cycle_count + 8'd1;
                    product <= candidate * candidate;
                end
                
                DIVIDE: begin
                    remainder <= remaining % candidate;
                    divisible <= (remainder == 16'd0);
                end
                
                UPDATE: begin
                    if (divisible) begin
                        remaining <= remaining / candidate;
                        max_factor <= candidate;
                    end else begin
                        candidate <= candidate + 8'd2;
                    end
                end
                
                DONE_STATE: begin
                    if (remaining > 16'd1) begin
                        max_factor <= remaining;
                    end
                    result <= max_factor;
                    done <= 1'b1;
                end
                
                default: begin
                    n_reg <= 16'd0;
                    remaining <= 16'd0;
                    candidate <= 8'd0;
                    max_factor <= 16'd0;
                    product <= 16'd0;
                    remainder <= 16'd0;
                    divisible <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end
endmodule