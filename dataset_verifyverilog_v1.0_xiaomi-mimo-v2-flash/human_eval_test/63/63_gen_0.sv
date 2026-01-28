module fibfib_iterative (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_N   = 3'd1;
    localparam [2:0] LOAD_BASE = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] counter;          // Iteration counter
    reg [15:0] a, b, c;         // Last three values: a=fibfib(i-3), b=fibfib(i-2), c=fibfib(i-1)
    reg [7:0] target_n;         // Store target n
    reg [7:0] cycle_count;      // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Computation logic
    wire [15:0] sum_next;
    assign sum_next = a + b + c;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 8'd0;
            a <= 16'd0;
            b <= 16'd0;
            c <= 16'd0;
            target_n <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        target_n <= n;
                        state <= CHECK_N;
                    end
                end

                CHECK_N: begin
                    // Check special cases: n=0, n=1, n=2
                    if (target_n == 8'd0 || target_n == 8'd1) begin
                        result <= 16'd0;
                        state <= FINISH;
                    end else if (target_n == 8'd2) begin
                        result <= 16'd1;
                        state <= FINISH;
                    end else begin
                        // Initialize for n >= 3
                        a <= 16'd0;  // fibfib(0)
                        b <= 16'd0;  // fibfib(1)
                        c <= 16'd1;  // fibfib(2)
                        counter <= 8'd2;  // Current index
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute next value: fibfib(i) = a + b + c
                    // Shift window: a = b, b = c, c = sum_next
                    a <= b;
                    b <= c;
                    c <= sum_next;
                    counter <= counter + 8'd1;
                    
                    // Check completion
                    if (counter + 8'd1 >= target_n) begin
                        result <= sum_next;  // This is fibfib(target_n)
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule