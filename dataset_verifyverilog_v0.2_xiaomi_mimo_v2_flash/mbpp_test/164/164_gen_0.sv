module equivalent_divisors (
    input clk,
    input rst_n,
    input start,
    input [7:0] num1,
    input [7:0] num2,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CALC1 = 3'b001;  // Iterating for num1
    localparam CALC2 = 3'b010;  // Iterating for num2
    localparam COMPARE = 3'b011;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [7:0] i1, i2;           // Iterators for num1 and num2
    reg [15:0] sum1, sum2;      // Accumulators (16-bit to prevent overflow for max 255)
    reg [7:0] n1_reg, n2_reg;   // Registers to store inputs
    reg [7:0] sq_cnt;           // Counter to check i*i > n

    // Temporary variables for combinational logic
    reg [15:0] next_sum1;
    reg [15:0] next_sum2;
    reg [7:0] next_i1;
    reg [7:0] next_i2;
    reg [2:0] next_state;
    reg [7:0] sq1_next, sq2_next;

    // Combinational logic for state transitions and operations
    always @(*) begin
        // Default assignments
        next_state = state;
        next_sum1 = sum1;
        next_sum2 = sum2;
        next_i1 = i1;
        next_i2 = i2;
        sq1_next = i1 * i1; // Implicit wire for square logic
        sq2_next = i2 * i2; // Implicit wire for square logic

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC1;
                    next_sum1 = 16'd1;  // Initialize sum with 1
                    next_sum2 = 16'd1;
                    next_i1 = 8'd2;     // Start checking from 2
                    next_i2 = 8'd2;
                end
            end

            CALC1: begin
                // Iterate for num1
                if (sq1_next > n1_reg) begin
                    next_state = CALC2; // Move to next number
                end else begin
                    if (n1_reg % i1 == 0) begin
                        // Divisible: add i and n/i
                        if (i1 == (n1_reg / i1)) begin
                            next_sum1 = sum1 + i1; // Perfect square case
                        end else begin
                            next_sum1 = sum1 + i1 + (n1_reg / i1);
                        end
                    end
                    next_i1 = i1 + 1;
                end
            end

            CALC2: begin
                // Iterate for num2
                if (sq2_next > n2_reg) begin
                    next_state = COMPARE;
                end else begin
                    if (n2_reg % i2 == 0) begin
                        if (i2 == (n2_reg / i2)) begin
                            next_sum2 = sum2 + i2;
                        end else begin
                            next_sum2 = sum2 + i2 + (n2_reg / i2);
                        end
                    end
                    next_i2 = i2 + 1;
                end
            end

            COMPARE: begin
                next_state = DONE;
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            sum1 <= 16'd0;
            sum2 <= 16'd0;
            i1 <= 8'd0;
            i2 <= 8'd0;
            n1_reg <= 8'd0;
            n2_reg <= 8'd0;
        end else begin
            // Update state
            state <= next_state;

            // Update internal registers based on current state
            case (state)
                IDLE: begin
                    if (start) begin
                        n1_reg <= num1;
                        n2_reg <= num2;
                    end
                end
                
                CALC1: begin
                    sum1 <= next_sum1;
                    i1 <= next_i1;
                end
                
                CALC2: begin
                    sum2 <= next_sum2;
                    i2 <= next_i2;
                end
                
                COMPARE: begin
                    // Output updates at COMPARE transition to DONE
                end
                
                DONE: begin
                    // Outputs already set in previous cycle logic or here
                end
            endcase

            // Output logic control
            if (next_state == COMPARE) begin
                result <= (next_sum1 == next_sum2);
                done <= 1'b1;
            end else if (next_state == IDLE) begin
                done <= 1'b0;
            end else if (next_state != COMPARE && state == DONE && !start) begin
                done <= 1'b0;
            end
        end
    end

endmodule