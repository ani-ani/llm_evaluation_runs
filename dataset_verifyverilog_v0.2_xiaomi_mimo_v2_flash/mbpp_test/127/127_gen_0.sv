module multiply_int (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] x,
    input signed [15:0] y,
    output reg signed [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Internal Registers
    reg [1:0] state, next_state;
    reg signed [15:0] x_reg;
    reg signed [15:0] y_reg;
    reg signed [31:0] acc;
    reg [15:0] counter;
    reg res_sign;
    reg done_next;
    reg signed [31:0] result_next;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            result <= result_next;
            done <= done_next;
        end
    end

    // Next State Logic & Output Logic (Combined)
    always @(*) begin
        // Default assignments
        next_state = state;
        done_next = done;
        result_next = result;
        
        // Internal combinational logic defaults
        // Note: To keep sensitivity list clean, we rely on the state to control updates
        // but we must declare signals used in sequential block as reg if assigned in always block.
        // Since x_reg, y_reg, acc, counter are updated in sequential block, we assign them inside the case.
        // However, to properly scope them, we define next versions or update directly in sequential block.
        // A safer pattern for this specific "iterative" request without an explicit clock in the instruction 
        // other than the interface means we must be careful about how we handle the loop.
        // Since 'start' is synchronous, we treat everything as synchronous.
    end

    // Logic to handle the iterative addition (Main FSM logic)
    // We split the logic: State transitions and datapath updates
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Flops
            state <= IDLE;
            result <= 0;
            done <= 0;
            acc <= 0;
            counter <= 0;
            x_reg <= 0;
            y_reg <= 0;
            res_sign <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Capture inputs
                        x_reg <= x;
                        y_reg <= y;
                        
                        // Pre-process: Determine sign
                        // Result is negative if signs are different (excluding zero which handles naturally)
                        res_sign <= (x[15] ^ y[15]);
                        
                        // Take absolute values
                        // If negative, 2's complement is bitwise invert + 1
                        // If positive, value remains same
                        // Use ternary to get magnitude
                        
                        // If y is 0, skip to done immediately
                        if (y == 0) begin
                            state <= DONE;
                            acc <= 0;
                        end else begin
                            // Start processing
                            state <= PROCESSING;
                            // Initialize Accumulator
                            acc <= 0;
                            // Initialize Counter (magnitude of y)
                            if (y[15])
                                counter <= (~y) + 1;
                            else
                                counter <= y;
                            // Initialize X magnitude for addition
                            // (We could calculate magnitude here or in processing, let's do it here)
                            if (x[15])
                                x_reg <= (~x) + 1; // Convert to positive magnitude
                            else
                                x_reg <= x;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end

                PROCESSING: begin
                    if (counter == 0) begin
                        // Calculation done, apply sign
                        state <= DONE;
                        if (res_sign)
                            result <= -acc;
                        else
                            result <= acc;
                    end else begin
                        // Add x magnitude to accumulator
                        acc <= acc + x_reg;
                        // Decrement counter
                        counter <= counter - 1;
                    end
                end

                DONE: begin
                    // Stay in done state until reset or new start
                    // The instruction says "Latch result and assert done".
                    // Done is asserted in this state.
                    done <= 1;
                    if (start) begin
                        // Restart logic if start is held high or reasserted (optional behavior, usually stay in done until reset)
                        // But to be robust, if start is asserted again, restart.
                         state <= IDLE;
                         done <= 0;
                    end else begin
                         state <= DONE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule