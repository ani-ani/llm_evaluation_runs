module perrin_sum (
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam CALC = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [15:0] result_next;
    reg done_next;
    
    // Internal registers for Perrin sequence and summation
    reg [15:0] a, b, c, sum;
    reg [15:0] a_n, b_n, c_n, sum_n;
    reg [3:0] i, i_n;
    
    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            a <= 16'b0;
            b <= 16'b0;
            c <= 16'b0;
            sum <= 16'b0;
            i <= 4'b0;
        end else begin
            state <= next_state;
            result <= result_next;
            done <= done_next;
            a <= a_n;
            b <= b_n;
            c <= c_n;
            sum <= sum_n;
            i <= i_n;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments to avoid latches
        next_state = state;
        result_next = result;
        done_next = done;
        a_n = a;
        b_n = b;
        c_n = c;
        sum_n = sum;
        i_n = i;
        
        case (state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                // Initialize sequence: P(0)=3, P(1)=0, P(2)=2
                a_n = 16'd3;
                b_n = 16'd0;
                c_n = 16'd2;
                sum_n = 16'd3; // Sum includes P(0)
                i_n = 4'd0;
                result_next = 16'b0;
                next_state = CALC;
            end
            
            CALC: begin
                // Loop until i == N (i.e., while i < N)
                if (i < N) begin
                    // Calculate next Perrin number: P(n) = P(n-2) + P(n-3) = b + a
                    // Update registers: shift left (a=b, b=c, c=new value)
                    // Add the value that was 'b' (P(i+1)) to sum
                    
                    // Logic: Shift then Add 'a'
                    a_n = b;
                    b_n = c;
                    c_n = a + b; // d = a + b
                    
                    // Add the new 'a' (which corresponds to P(i+1))
                    sum_n = sum + a_n;
                    
                    // Increment counter
                    i_n = i + 1;
                end else begin
                    // Loop finished, result is ready
                    result_next = sum;
                    next_state = DONE;
                end
            end
            
            DONE: begin
                // Done signal is already asserted (controlled by sequential logic reset)
                // Stay in DONE until reset
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule