module dp_recurrence (
    input clk,
    input rst_n,
    input start,
    input [3:0] x_in,
    input [3:0] y_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [15:0] MAX_X = 16'd15;
    localparam [15:0] MAX_Y = 16'd15;
    
    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT_BND = 3'd1;
    localparam [2:0] INIT_FIB = 3'd2;
    localparam [2:0] COMPUTE  = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;
    localparam [2:0] FINISH   = 3'd5;
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;
    
    // Index counters
    reg [3:0] i;
    reg [3:0] j;
    
    // Fibonacci calculation
    reg [31:0] fib_prev;
    reg [31:0] fib_curr;
    reg [31:0] fib_next;
    reg [3:0] fib_idx;
    
    // Result array (16x16 = 256 elements, packed as 16 rows of 16 columns each)
    // We'll use a 2D array flattened for easier indexing
    reg [31:0] f_array [0:15][0:15];
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT_BND : IDLE;
            INIT_BND:   next_state = (i >= 4'd15 && j >= 4'd15) ? INIT_FIB : INIT_BND;
            INIT_FIB:   next_state = (fib_idx > 4'd15) ? COMPUTE : INIT_FIB;
            COMPUTE:    next_state = (i > x_in || (i == x_in && j > y_in)) ? OUTPUT : COMPUTE;
            OUTPUT:     next_state = FINISH;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
    
    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            fib_prev <= 32'd0;
            fib_curr <= 32'd0;
            fib_next <= 32'd0;
            fib_idx <= 4'd0;
            
            // Initialize all array elements to 0
            for (integer r = 0; r < 16; r = r + 1) begin
                for (integer c = 0; c < 16; c = c + 1) begin
                    f_array[r][c] <= 32'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    fib_prev <= 32'd0;
                    fib_curr <= 32'd0;
                    fib_next <= 32'd0;
                    fib_idx <= 4'd0;
                    
                    // Reset array elements that will be used
                    for (integer r = 0; r < 16; r = r + 1) begin
                        for (integer c = 0; c < 16; c = c + 1) begin
                            f_array[r][c] <= 32'd0;
                        end
                    end
                end
                
                INIT_BND: begin
                    // Initialize boundaries F(i,0) and F(0,i)
                    // Base cases: F(0,0)=0
                    if (i == 4'd0 && j == 4'd0) begin
                        f_array[0][0] <= 32'd0;
                    end
                    // Initialize row 0 (except (0,0))
                    else if (j > 4'd0 && i == 4'd0) begin
                        f_array[0][j] <= 32'd1;  // Fibonacci(1) = 1
                    end
                    // Initialize column 0 (except (0,0))
                    else if (i > 4'd0 && j == 4'd0) begin
                        f_array[i][0] <= 32'd1;  // Fibonacci(1) = 1
                    end
                    
                    // Move to next boundary cell
                    if (i < 4'd15) begin
                        i <= i + 4'd1;
                    end else if (j < 4'd15) begin
                        i <= 4'd0;
                        j <= j + 4'd1;
                    end
                end
                
                INIT_FIB: begin
                    // Compute Fibonacci numbers for boundaries
                    if (fib_idx == 4'd0) begin
                        fib_prev <= 32'd0;
                        fib_curr <= 32'd0;
                    end else if (fib_idx == 4'd1) begin
                        fib_prev <= 32'd0;
                        fib_curr <= 32'd1;
                    end else begin
                        // Fib(n) = Fib(n-1) + Fib(n-2)
                        fib_next <= (fib_curr + fib_prev) % MOD;
                        fib_prev <= fib_curr;
                        fib_curr <= fib_next;
                    end
                    
                    // Update boundaries for indices > 1
                    if (fib_idx >= 4'd2 && fib_idx <= 4'd15) begin
                        f_array[0][fib_idx] <= fib_next;
                        f_array[fib_idx][0] <= fib_next;
                    end
                    
                    fib_idx <= fib_idx + 4'd1;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute F(i,j) = F(i-1,j) + F(i,j-1)
                    if (i >= 4'd1 && j >= 4'd1) begin
                        f_array[i][j] <= (f_array[i-1][j] + f_array[i][j-1]) % MOD;
                    end
                    
                    // Move to next cell (row-by-row, left-to-right)
                    if (j < 4'd15) begin
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                    end
                end
                
                OUTPUT: begin
                    result <= f_array[x_in][y_in];
                    done <= 1'b1;
                end
                
                FINISH: begin
                    done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule