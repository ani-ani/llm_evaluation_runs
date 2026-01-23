module special_factorial(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALCULATE_FACT = 3'd1;
    localparam [2:0] MULTIPLY = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Counters and registers
    reg [7:0] k;           // Outer loop counter (n down to 1)
    reg [7:0] fact_counter; // Inner counter for factorial calculation
    reg [63:0] fact_result; // Current factorial result
    reg [63:0] accumulator; // Accumulated product

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine for main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            k <= 8'd0;
            fact_counter <= 8'd0;
            fact_result <= 64'd1;
            accumulator <= 64'd1;
            result <= 64'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALCULATE_FACT;
                        k <= n;
                        accumulator <= 64'd1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALCULATE_FACT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate k! using fact_counter
                    if (fact_counter == 8'd0) begin
                        fact_result <= 64'd1;
                        fact_counter <= k;
                    end else begin
                        fact_result <= fact_result * fact_counter;
                        fact_counter <= fact_counter - 8'd1;
                        
                        if (fact_counter == 8'd0) begin
                            next_state <= MULTIPLY;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                MULTIPLY: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Multiply accumulator by current factorial
                    accumulator <= accumulator * fact_result;
                    
                    // Move to next k value
                    k <= k - 8'd1;
                    
                    if (k == 8'd0) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= CALCULATE_FACT;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= accumulator;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule