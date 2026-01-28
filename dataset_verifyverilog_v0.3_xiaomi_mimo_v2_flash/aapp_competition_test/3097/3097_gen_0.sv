module fib_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] A,
    input wire [31:0] B,
    output reg [31:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] NEXT_ITER = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [31:0] fib_a;
    reg [31:0] fib_b;
    reg [31:0] fib_c;
    reg [31:0] count;
    reg [31:0] iter;
    
    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: begin
                if (A > B || A > 32'd1000000 || B > 32'd1000000)
                    next_state = FINISH;
                else
                    next_state = CHECK;
            end
            CHECK: begin
                if (fib_a > B)
                    next_state = FINISH;
                else if (fib_a >= A && fib_a <= B)
                    next_state = COMPUTE;
                else
                    next_state = NEXT_ITER;
            end
            COMPUTE: begin
                next_state = NEXT_ITER;
            end
            NEXT_ITER: begin
                if (fib_a > B)
                    next_state = FINISH;
                else
                    next_state = CHECK;
            end
            FINISH: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = FINISH;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            fib_a <= 32'd0;
            fib_b <= 32'd0;
            fib_c <= 32'd0;
            count <= 32'd0;
            iter <= 32'd0;
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                end
                INIT: begin
                    fib_a <= 32'd1;
                    fib_b <= 32'd1;
                    fib_c <= 32'd2;
                    count <= 32'd0;
                    iter <= 32'd1;
                end
                CHECK: begin
                    // No state changes needed here
                end
                COMPUTE: begin
                    count <= count + 32'd1;
                end
                NEXT_ITER: begin
                    if (fib_a <= B) begin
                        fib_a <= fib_b;
                        fib_b <= fib_c;
                        fib_c <= fib_a + fib_b;
                        iter <= iter + 32'd1;
                    end
                end
                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule