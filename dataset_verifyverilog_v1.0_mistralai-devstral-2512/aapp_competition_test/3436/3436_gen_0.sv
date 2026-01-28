module Recurrence2D(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] x_in,
    input wire [3:0] y_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // State machine
    reg [2:0] state;
    reg [7:0] cycle_count;

    // DP table (16x16)
    reg [31:0] F [0:15];
    integer i, j;

    // Fibonacci lookup table for boundaries
    reg [31:0] fib [0:15];

    // Current computation position
    reg [3:0] current_x;
    reg [3:0] current_y;

    // Initialize Fibonacci sequence
    initial begin
        fib[0] = 32'd0;
        fib[1] = 32'd1;
        for (i = 2; i < 16; i = i + 1) begin
            fib[i] = (fib[i-1] + fib[i-2]) % MOD;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            cycle_count <= 8'd0;
            current_x <= 4'd0;
            current_y <= 4'd0;
            
            // Initialize DP table
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    F[i][j] <= 32'd0;
                end
            end
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
                    
                    // Initialize boundaries
                    for (i = 0; i < 16; i = i + 1) begin
                        F[0][i] <= fib[i];
                        F[i][0] <= fib[i];
                    end
                    
                    // Set base cases
                    F[0][0] <= 32'd0;
                    F[0][1] <= 32'd1;
                    F[1][0] <= 32'd1;
                    
                    // Initialize computation position
                    current_x <= 4'd1;
                    current_y <= 4'd1;
                    
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute F[current_x][current_y]
                    F[current_x][current_y] <= (F[current_x-1][current_y] + F[current_x][current_y-1]) % MOD;
                    
                    // Move to next position (row-major order)
                    if (current_y == 4'd15) begin
                        if (current_x == 4'd15) begin
                            state <= OUTPUT;
                        end else begin
                            current_x <= current_x + 4'd1;
                            current_y <= 4'd1;
                        end
                    end else begin
                        current_y <= current_y + 4'd1;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result <= F[x_in][y_in];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule