module simple_power(
    input clk,
    input rst_n,
    input start,
    input [7:0] x,
    input [7:0] n,
    output reg result,
    output reg done
);

// State encoding
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

// State register
reg [1:0] state;

// Datapath registers
reg [31:0] current_power;
reg [4:0] k;

// Next state logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                end else begin
                    state <= IDLE;
                end
            end
            PROCESSING: begin
                if ((current_power[7:0] == x) || 
                    (current_power[31:0] > {24'b0, x}) || 
                    (k > 31)) begin
                    state <= DONE;
                end else begin
                    state <= PROCESSING;
                end
            end
            DONE: begin
                if (!rst_n || start) begin
                    state <= IDLE;
                end else begin
                    state <= DONE;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

// Output and datapath logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 1'b0;
        done <= 1'b0;
        current_power <= 32'd0;
        k <= 5'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                result <= 1'b0;
                if (start) begin
                    // Special cases handling at start
                    if (x == 8'd1) begin
                        // x=1 is always n^0 (except n=0, but 0^0=1 by spec)
                        result <= 1'b1;
                        done <= 1'b1;
                        current_power <= 32'd1;
                        k <= 5'd0;
                        state <= DONE;
                    end else if (n == 8'd0) begin
                        // n=0: only x=1 is power, but x!=1 (handled above)
                        result <= 1'b0;
                        done <= 1'b1;
                        current_power <= 32'd0;
                        k <= 5'd0;
                        state <= DONE;
                    end else if (n == 8'd1) begin
                        // n=1: only x=1 is power, but x!=1 (handled above)
                        result <= 1'b0;
                        done <= 1'b1;
                        current_power <= 32'd1;
                        k <= 5'd0;
                        state <= DONE;
                    end else begin
                        // Normal case: start with n^0 = 1
                        current_power <= 32'd1;
                        k <= 5'd0;
                    end
                end
            end
            PROCESSING: begin
                // Check current_power against x
                if (current_power[7:0] == x) begin
                    result <= 1'b1;
                    done <= 1'b1;
                    state <= DONE;
                end else if (current_power[31:0] > {24'b0, x}) begin
                    result <= 1'b0;
                    done <= 1'b1;
                    state <= DONE;
                end else if (k > 31) begin
                    result <= 1'b0;
                    done <= 1'b1;
                    state <= DONE;
                end else begin
                    // Multiply and increment
                    current_power <= current_power * n;
                    k <= k + 1;
                end
            end
            DONE: begin
                // Hold outputs until reset or new start
                done <= 1'b1;
                // result is already set
                if (!rst_n || start) begin
                    done <= 1'b0;
                    result <= 1'b0;
                end
            end
        endcase
    end
end

endmodule

// Testbench module
module tb_simple_power();
    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] x;
    reg [7:0] n;
    wire result;
    wire done;
    
    integer errors;
    integer test_num;
    
    simple_power dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .x(x),
        .n(n),
        .result(result),
        .done(done)
    );
    
    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    task wait_done;
        begin
            wait(done == 1);
            #1;
        end
    endtask
    
    task check_result;
        input [7:0] exp_x;
        input [7:0] exp_n;
        input exp_result;
        input integer t_num;
        begin
            start = 1;
            x = exp_x;
            n = exp_n;
            #10;
            start = 0;
            wait_done;
            if (result !== exp_result) begin
                $display("Error test %0d: x=%0d n=%0d expected %0d got %0d", 
                         t_num, exp_x, exp_n, exp_result, result);
                errors = errors + 1;
            end else begin
                $display("Pass test %0d: x=%0d n=%0d result=%0d", 
                         t_num, exp_x, exp_n, result);
            end
            test_num = test_num + 1;
        end
    endtask
    
    initial begin
        errors = 0;
        test_num = 1;
        
        // Initialize
        rst_n = 0;
        start = 0;
        x = 0;
        n = 0;
        #20;
        
        // Release reset
        rst_n = 1;
        #10;
        
        $display("Starting simple_power tests...");
        
        // Test cases for powers up to 2^31
        
        // Base 2 powers
        check_result(1, 2, 1, test_num);   // 2^0 = 1
        check_result(2, 2, 1, test_num);   // 2^1 = 2
        check_result(4, 2, 1, test_num);   // 2^2 = 4
        check_result(8, 2, 1, test_num);   // 2^3 = 8
        check_result(16, 2, 1, test_num);  // 2^4 = 16
        check_result(32, 2, 1, test_num);  // 2^5 = 32
        check_result(64, 2, 1, test_num);  // 2^6 = 64
        check_result(128, 2, 1, test_num); // 2^7 = 128
        check_result(255, 2, 0, test_num); // 255 is not power of 2
        
        // Base 3 powers
        check_result(1, 3, 1, test_num);   // 3^0 = 1
        check_result(3, 3, 1, test_num);   // 3^1 = 3
        check_result(9, 3, 1, test_num);   // 3^2 = 9
        check_result(27, 3, 1, test_num);  // 3^3 = 27
        check_result(81, 3, 1, test_num);  // 3^4 = 81
        check_result(243, 3, 1, test_num); // 3^5 = 243
        check_result(255, 3, 0, test_num); // 255 not power of 3
        
        // Base 10 powers
        check_result(1, 10, 1, test_num);  // 10^0 = 1
        check_result(10, 10, 1, test_num); // 10^1 = 10
        check_result(100, 10, 1, test_num); // 10^2 = 100
        check_result(255, 10, 0, test_num); // 255 not power of 10
        
        // Edge cases
        check_result(1, 0, 1, test_num);   // 0^0 = 1
        check_result(2, 0, 0, test_num);   // 0^k (k>0) = 0, not 2
        check_result(0, 0, 0, test_num);   // 0 is not a power (0^k = 0 or undefined)
        
        check_result(1, 1, 1, test_num);   // 1^k = 1
        check_result(5, 1, 0, test_num);   // 1^k = 1, not 5
        
        check_result(255, 255, 1, test_num); // 255^1 = 255
        check_result(1, 255, 1, test_num);   // 255^0 = 1
        check_result(200, 255, 0, test_num); // 200 not power of 255
        
        // Test overflow case (k > 31)
        // For n=2, k=32 would exceed 32-bit, but we stop at k=31
        check_result(255, 2, 0, test_num); // Already tested
        
        // Power of 2 that wraps around 8-bit but is larger
        // For n=2, k=8 gives 256, which is > 255
        check_result(0, 2, 0, test_num);   // 256 > 255, so not equal to 0
        
        // Random non-powers
        check_result(15, 2, 0, test_num);  // 15 not power of 2
        check_result(50, 10, 0, test_num); // 50 not power of 10
        check_result(99, 3, 0, test_num);  // 99 not power of 3
        
        // Zero handling
        check_result(0, 5, 0, test_num);   // 5^k > 0, never 0
        check_result(0, 0, 0, test_num);   // Already tested
        
        // Large n
        check_result(200, 200, 1, test_num); // 200^1 = 200
        check_result(255, 200, 0, test_num); // 255 not power of 200
        
        // Test timing (32 cycles worst case)
        // We can verify done goes high within 32 cycles for non-power
        $display("
Timing test: n=2, x=255 (not a power, should take <= 32 cycles)");
        start = 1;
        x = 255;
        n = 2;
        #10;
        start = 0;
        fork
            begin : timeout
                #330; // 32 cycles + margin
                if (!done) begin
                    $display("Error: Timeout - done not asserted within 32 cycles");
                    errors = errors + 1;
                end
            end
            begin : monitor
                wait(done == 1);
                $display("Pass: done asserted at cycle %0t", $time/10);
                disable timeout;
            end
        join
        
        #20;
        
        if (errors == 0)
            $display("
*** ALL TESTS PASSED ***");
        else
            $display("
*** %0d TESTS FAILED ***", errors);
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10000;
        $display("Error: Simulation timeout");
        $finish;
    end
    
endmodule