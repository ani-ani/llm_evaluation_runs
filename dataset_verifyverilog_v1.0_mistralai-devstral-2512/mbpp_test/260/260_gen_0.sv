module NSWPrime(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_COMPUTE = 2'd1;
    localparam [1:0] STATE_DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] count;
    reg [31:0] prev;
    reg [31:0] prev2;
    reg [31:0] next;
    reg [3:0] current_n;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= STATE_IDLE;
            result <= 32'd0;
            done <= 1'b0;
            count <= 4'd0;
            prev <= 32'd0;
            prev2 <= 32'd0;
            next <= 32'd0;
            current_n <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load n and initialize for computation
                        current_n <= n;
                        count <= 4'd0;
                        prev <= 32'd1;  // NSW(1)
                        prev2 <= 32'd1; // NSW(0)
                        
                        // Handle n=0 and n=1 cases immediately
                        if (current_n == 4'd0 || current_n == 4'd1) begin
                            result <= 32'd1;
                            state <= STATE_DONE;
                        end else begin
                            state <= STATE_COMPUTE;
                        end
                    end
                end

                STATE_COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute next value: NSW(n) = 2*NSW(n-1) + NSW(n-2)
                    next <= (prev << 1) + prev2;
                    
                    // Update previous values
                    prev2 <= prev;
                    prev <= next;
                    
                    // Increment iteration count
                    count <= count + 4'd1;
                    
                    // Check if computation is complete
                    if (count == (current_n - 4'd2) || cycle_count >= MAX_CYCLES) begin
                        result <= prev;
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule