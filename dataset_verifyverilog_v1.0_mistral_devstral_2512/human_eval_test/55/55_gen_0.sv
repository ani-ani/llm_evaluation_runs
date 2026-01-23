module fibonacci(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] INIT      = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] DONE      = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    reg [15:0] a;
    reg [15:0] b;
    reg [15:0] next_fib;
    reg [4:0] counter;
    reg [4:0] target;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            a <= 16'd0;
            b <= 16'd0;
            counter <= 5'd0;
            target <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    a <= 16'd0;
                    b <= 16'd1;
                    counter <= 5'd0;
                    target <= n;
                    state <= CALCULATE;
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute next Fibonacci number
                    next_fib <= a + b;
                    a <= b;
                    b <= next_fib;
                    counter <= counter + 5'd1;
                    
                    // Check if done
                    if ((counter >= (target - 5'd1)) || (cycle_count >= MAX_CYCLES)) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Convert to Q16.16 format
                    result <= b << 16;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule