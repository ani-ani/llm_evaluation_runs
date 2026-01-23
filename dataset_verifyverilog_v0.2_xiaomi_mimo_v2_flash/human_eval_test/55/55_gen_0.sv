module fib(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam IDLE      = 3'b001;
    localparam INIT      = 3'b010;
    localparam CALCULATE = 3'b100;
    // Note: COMPLETE is implicitly handled by the logic going back to IDLE
    // The 'done' signal indicates the COMPLETE state.

    reg [2:0] state;
    reg [2:0] next_state;

    reg [31:0] fib_prev;
    reg [31:0] fib_curr;
    reg [15:0] counter;

    // State Register and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            fib_prev <= 32'b0;
            fib_curr <= 32'b0;
            counter <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    if (n == 16'd0) begin
                        result <= 32'b0;
                        done <= 1'b1;
                        state <= IDLE; // Go directly to idle after setting result
                    end else if (n == 16'd1) begin
                        result <= 32'b1;
                        done <= 1'b1;
                        state <= IDLE; // Go directly to idle after setting result
                    end else begin
                        // Initialize for n >= 2
                        fib_prev <= 32'b0; // F(0)
                        fib_curr <= 32'b1; // F(1)
                        counter <= 16'd1;  // We are at position 1
                        state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    if (counter < n - 1) begin
                        // Perform iteration
                        fib_prev <= fib_curr;
                        fib_curr <= fib_prev + fib_curr;
                        counter <= counter + 16'd1;
                        state <= CALCULATE;
                    end else begin
                        // Computation complete
                        result <= fib_curr + fib_prev; // The final addition happens here or previous cycle depending on exact clock alignment. 
                        // Let's verify logic:
                        // If counter == n-2, we enter here, update fib_curr to F(n-1)+F(n-2)=F(n-1)?? Wait.
                        // Let's trace: 
                        // Initial: prev=0, curr=1, count=1. Target n.
                        // We need to perform (n-1) additions/shifts to get F(n).
                        // i=1 to n-1.
                        // Step 1: new_curr = 0+1 = 1. count=2.
                        // Step k: new_curr = F(k)+F(k-1) = F(k+1). count=k+1.
                        // We want count to reach n.
                        // If counter < n (or n-1?), let's check:
                        // If n=2: count=1. Loop condition: 1 < 2-1 (1<1)? False. Goes to Else. Result = 1+0 = 1. Correct F(2).
                        // If n=3: count=1. Loop: 1 < 2 -> True. Update: prev=1, curr=1, count=2. 
                        // Next clock: count=2. Loop: 2 < 2 -> False. Else. Result = 1+1 = 2. Correct F(3).
                        // If n=4: count=1. Loop: 1<3 -> True. (prev=1, curr=1, count=2)
                        // count=2. Loop: 2<3 -> True. (prev=1, curr=2, count=3)
                        // count=3. Loop: 3<3 -> False. Result = 2+1 = 3. Correct F(4).
                        // This logic works.
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
