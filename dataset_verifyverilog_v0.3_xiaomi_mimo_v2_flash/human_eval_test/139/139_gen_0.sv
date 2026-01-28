module special_factorial (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE              = 3'd0;
    localparam [2:0] CALCULATE_FACT    = 3'd1;
    localparam [2:0] MULTIPLY          = 3'd2;
    localparam [2:0] DONE              = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [63:0] accumulator;
    reg [63:0] factorial_result;
    reg [7:0] k;               // Outer loop counter: n down to 1
    reg [7:0] fact_i;          // Inner loop counter for factorial calculation
    reg [63:0] inner_acc;      // Accumulator for factorial calculation
    reg [7:0] saved_n;         // Store n value when start is asserted

    // Combinational logic for next state and factorial calculation
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALCULATE_FACT;
                else
                    next_state = IDLE;
            end
            CALCULATE_FACT: begin
                if (fact_i > 8'd1)
                    next_state = CALCULATE_FACT;
                else
                    next_state = MULTIPLY;
            end
            MULTIPLY: begin
                if (k > 8'd1)
                    next_state = CALCULATE_FACT;
                else
                    next_state = DONE;
            end
            DONE: begin
                // Stay in DONE until reset or new start
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            accumulator <= 64'd1;
            factorial_result <= 64'd1;
            k <= 8'd0;
            fact_i <= 8'd0;
            inner_acc <= 64'd1;
            saved_n <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 64'd0;
                    accumulator <= 64'd1;
                    factorial_result <= 64'd1;
                    if (start) begin
                        saved_n <= n;
                        k <= n;
                        fact_i <= n;
                        inner_acc <= 64'd1;
                    end
                end
                
                CALCULATE_FACT: begin
                    // Calculate k! where k is stored in fact_i
                    if (fact_i > 8'd1) begin
                        inner_acc <= inner_acc * fact_i;
                        fact_i <= fact_i - 8'd1;
                    end
                end
                
                MULTIPLY: begin
                    // fact_i is now 1, inner_acc holds k!
                    factorial_result <= inner_acc;
                    accumulator <= accumulator * inner_acc;
                    k <= k - 8'd1;
                    if (k > 8'd1) begin
                        fact_i <= k - 8'd1;
                        inner_acc <= 64'd1;
                    end
                end
                
                DONE: begin
                    result <= accumulator;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule