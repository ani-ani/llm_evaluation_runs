module TopModule(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] DONE     = 2'd2;
    localparam [7:0] MAX_N    = 8'd256;
    localparam [15:0] MAX_CYCLES = 16'd2000;
    
    // Registers
    reg [1:0] state, next_state;
    reg [7:0] a, b, c;
    reg [15:0] count;
    reg [15:0] cycle_counter;
    reg [15:0] sum_ab;
    reg [15:0] sq_c;
    reg [15:0] a_sq_reg;
    reg [15:0] b_sq_reg;
    reg [15:0] c_sq_reg;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                // Check completion: a reaches n, or cycle limit
                if (a >= n || cycle_counter >= MAX_CYCLES)
                    next_state = DONE;
                else
                    next_state = COMPUTE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State machine and computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            a <= 8'd0;
            b <= 8'd0;
            c <= 8'd0;
            count <= 16'd0;
            cycle_counter <= 16'd0;
            sum_ab <= 16'd0;
            sq_c <= 16'd0;
            a_sq_reg <= 16'd0;
            b_sq_reg <= 16'd0;
            c_sq_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize computation
                        a <= 8'd0;
                        b <= 8'd0;
                        c <= 8'd1;
                        count <= 16'd0;
                        cycle_counter <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    // Compute squares (16-bit to prevent overflow)
                    a_sq_reg <= a * a;
                    b_sq_reg <= b * b;
                    c_sq_reg <= c * c;
                    
                    // Check condition: ((a^2 + b^2) % n) == (c^2 % n)
                    sum_ab <= (a * a) + (b * b);
                    sq_c <= c * c;
                    
                    // Compute modulo and compare
                    if (n > 8'd1 && a < n && b < n && c < n) begin
                        if (n == 8'd256) begin
                            // Special case: n=256 uses full 16-bit modulo
                            if ((sum_ab[15:0] % 256) == (sq_c[15:0] % 256)) begin
                                count <= count + 16'd1;
                            end
                        end else begin
                            // General case: n <= 255, use safe comparison
                            if ((sum_ab % n) == (sq_c % n)) begin
                                count <= count + 16'd1;
                            end
                        end
                    end
                    
                    // Loop increment logic
                    c <= c + 8'd1;
                    if (c >= n) begin
                        c <= 8'd1;
                        b <= b + 8'd1;
                        if (b >= n) begin
                            b <= a;  // Reset b to a for next iteration
                            a <= a + 8'd1;
                        end
                    end
                end
                
                DONE: begin
                    result <= count;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule