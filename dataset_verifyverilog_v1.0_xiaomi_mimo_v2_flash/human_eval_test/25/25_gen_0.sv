module prime_factorizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] factors [0:7],
    output reg [3:0] factor_count,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [15:0] remainder;
    reg [15:0] divisor;
    reg [3:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Index for array initialization
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            remainder <= 16'd0;
            divisor <= 16'd0;
            count <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            factor_count <= 4'd0;
            // Initialize factors array
            for (i = 0; i < 8; i = i + 1) begin
                factors[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Check input validity
                        if (n >= 16'd2 && n <= 16'd65535) begin
                            state <= CALCULATING;
                            remainder <= n;
                            divisor <= 16'd2;
                            count <= 4'd0;
                            // Reset factors array
                            for (i = 0; i < 8; i = i + 1) begin
                                factors[i] <= 16'd0;
                            end
                        end else begin
                            // Invalid input, go to done
                            state <= DONE_STATE;
                            valid <= 1'b0;
                            factor_count <= 4'd0;
                            for (i = 0; i < 8; i = i + 1) begin
                                factors[i] <= 16'd0;
                            end
                        end
                    end
                end
                
                CALCULATING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if remainder == 1 (success)
                    if (remainder == 16'd1) begin
                        state <= DONE_STATE;
                        valid <= 1'b1;
                        factor_count <= count;
                    end
                    // Check if divisor > remainder (fail)
                    else if (divisor > remainder) begin
                        state <= DONE_STATE;
                        valid <= 1'b0;
                        factor_count <= 4'd0;
                    end
                    // Check if we've exceeded max factors (fail)
                    else if (count >= 4'd8) begin
                        state <= DONE_STATE;
                        valid <= 1'b0;
                        factor_count <= 4'd0;
                    end
                    // Check if we've exceeded max cycles (fail)
                    else if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                        valid <= 1'b0;
                        factor_count <= 4'd0;
                    end
                    // Check if remainder is divisible by divisor
                    else if (remainder % divisor == 0) begin
                        // Store divisor in factors array
                        factors[count] <= divisor;
                        // Increment count
                        count <= count + 4'd1;
                        // Divide remainder by divisor
                        remainder <= remainder / divisor;
                        // Keep divisor the same (check again)
                    end
                    else begin
                        // Increment divisor
                        divisor <= divisor + 16'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                    factor_count <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        factors[i] <= 16'd0;
                    end
                end
            endcase
        end
    end

endmodule