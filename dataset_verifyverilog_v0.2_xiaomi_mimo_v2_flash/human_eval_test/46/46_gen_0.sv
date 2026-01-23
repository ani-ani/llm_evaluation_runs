module fib4 (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE = 2'b11;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] reg0, reg1, reg2, reg3; // Sequence registers: reg0 is most recent
    reg [15:0] next_reg0, next_reg1, next_reg2, next_reg3;
    reg [3:0] counter;
    reg [3:0] next_counter;
    reg [15:0] next_result;
    reg next_done;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            reg0 <= 16'd0;
            reg1 <= 16'd0;
            reg2 <= 16'd0;
            reg3 <= 16'd0;
            counter <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            reg0 <= next_reg0;
            reg1 <= next_reg1;
            reg2 <= next_reg2;
            reg3 <= next_reg3;
            counter <= next_counter;
            result <= next_result;
            done <= next_done;
        end
    end

    // Combinational logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_reg0 = reg0;
        next_reg1 = reg1;
        next_reg2 = reg2;
        next_reg3 = reg3;
        next_counter = counter;
        next_result = result;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = INIT;
                    next_reg0 = 16'd0;
                    next_reg1 = 16'd0;
                    next_reg2 = 16'd0;
                    next_reg3 = 16'd0;
                    next_counter = 4'd0;
                end
            end

            INIT: begin
                // Determine initial values based on n
                case (n)
                    4'd0: begin
                        next_result = 16'd0;
                        next_done = 1'b1;
                        next_state = DONE;
                    end
                    4'd1: begin
                        next_result = 16'd0;
                        next_done = 1'b1;
                        next_state = DONE;
                    end
                    4'd2: begin
                        next_result = 16'd2;
                        next_done = 1'b1;
                        next_state = DONE;
                    end
                    4'd3: begin
                        next_result = 16'd0;
                        next_done = 1'b1;
                        next_state = DONE;
                    end
                    default: begin // n >= 4
                        // Initialize sequence for n >= 4
                        // Sequence: 0, 0, 2, 0, 2, 4, 8, 14, ...
                        // We need to iterate starting from k=4
                        // At k=3: reg0=0, reg1=2, reg2=0, reg3=0 (looking backwards)
                        // Or we track current k value
                        // Let's initialize so that when we enter compute for k=4:
                        // reg3 (k-4), reg2 (k-3), reg1 (k-2), reg0 (k-1)
                        // For k=4: 
                        // reg3=0 (k-4=0), reg2=0 (k-3=1), reg1=2 (k-2=2), reg0=0 (k-3=3)
                        next_reg3 = 16'd0; // fib4(0)
                        next_reg2 = 16'd0; // fib4(1)
                        next_reg1 = 16'd2; // fib4(2)
                        next_reg0 = 16'd0; // fib4(3)
                        next_counter = 4'd4; // We start computing for k=4
                        next_state = COMPUTE;
                    end
                endcase
            end

            COMPUTE: begin
                // Compute new value
                // new_value = reg0 + reg1 + reg2 + reg3
                // Update shift: v3<=v2, v2<=v1, v1<=v0, v0<=new
                // But in our registers:
                // reg0 holds fib4(k-1)
                // reg1 holds fib4(k-2)
                // reg2 holds fib4(k-3)
                // reg3 holds fib4(k-4)
                
                next_reg3 = reg2;
                next_reg2 = reg1;
                next_reg1 = reg0;
                next_reg0 = reg0 + reg1 + reg2 + reg3;
                
                next_counter = counter + 1;
                
                if (counter == n) begin
                    // We have just computed fib4(n)
                    // It is currently in reg0
                    next_result = reg0;
                    next_done = 1'b1;
                    next_state = DONE;
                end else if (counter > n) begin
                    // Safety check, shouldn't happen with correct logic
                    next_done = 1'b1;
                    next_state = DONE;
                end else begin
                    // Continue computing
                    next_state = COMPUTE;
                end
            end

            DONE: begin
                next_done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule