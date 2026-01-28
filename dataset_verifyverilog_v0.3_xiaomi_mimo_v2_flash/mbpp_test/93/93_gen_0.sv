module PowerModule (
    input clk,
    input rst_n,
    input start,
    input [7:0] base,
    input [4:0] exponent,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [4:0] counter;        // Tracks remaining multiplications
    reg [31:0] accumulator;   // Holds the running result
    reg [7:0] base_reg;       // Store base for multi-cycle use
    reg computation_started;  // Flag to ensure single start pulse

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter <= 5'd0;
            accumulator <= 32'd0;
            base_reg <= 8'd0;
            computation_started <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    computation_started <= 1'b0;
                    
                    if (start && !computation_started) begin
                        computation_started <= 1'b1;
                        base_reg <= base;
                        
                        // Handle special case: exponent = 0
                        if (exponent == 5'd0) begin
                            accumulator <= 32'd1;
                            counter <= 5'd0;
                            state <= COMPLETE;
                        end else begin
                            // Initialize accumulator with base (first multiplication)
                            accumulator <= {24'd0, base};
                            // We need (exponent - 1) more multiplications
                            counter <= exponent - 5'd1;
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    if (counter > 5'd0) begin
                        // Multiply accumulator by base
                        accumulator <= accumulator * base_reg;
                        counter <= counter - 5'd1;
                        state <= COMPUTE;
                    end else begin
                        // Computation complete
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    result <= accumulator;
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