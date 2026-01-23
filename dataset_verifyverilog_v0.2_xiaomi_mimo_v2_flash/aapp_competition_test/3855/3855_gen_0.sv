module packet_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [4:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CALCULATING = 2'b01;
    localparam DONE = 2'b10;

    // State Registers
    reg [1:0] state, next_state;
    
    // Data Registers
    reg [15:0] n_reg, next_n_reg;
    reg [4:0] result_reg, next_result_reg;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 16'b0;
            result_reg <= 5'b0;
        end else begin
            state <= next_state;
            n_reg <= next_n_reg;
            result_reg <= next_result_reg;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_n_reg = n_reg;
        next_result_reg = result_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATING;
                    next_n_reg = n;
                    next_result_reg = 5'b0;
                end
            end
            
            CALCULATING: begin
                if (n_reg > 0) begin
                    // Shift n right by 1, increment count
                    next_n_reg = n_reg >> 1;
                    next_result_reg = result_reg + 1;
                end else begin
                    // n is 0, computation is done
                    next_state = DONE;
                end
            end
            
            DONE: begin
                // Wait for next start (goes back to IDLE implicitly if start is asserted again, 
                // but typically stays in DONE until reset or a specific trigger to go back)
                // Based on spec, we return to IDLE when start is asserted again or stay here?
                // Usually, done stays high until a new transaction starts.
                if (start) begin // If start is asserted again while in DONE, restart cycle
                     next_state = CALCULATING;
                     next_n_reg = n;
                     next_result_reg = 5'b0;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output Logic (Moore outputs)
    always @(*) begin
        done = 1'b0;
        result = 5'b0;
        
        case (state)
            DONE: begin
                done = 1'b1;
                result = result_reg;
            end
            default: begin
                done = 1'b0;
                result = 5'b0;
            end
        endcase
    end

endmodule
