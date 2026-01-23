module Element_wise_Division(
    input clk,
    input rst_n,
    input start,
    input [15:0] numerator [0:7],
    input [15:0] denominator [0:7],
    input [2:0] len,
    output reg [31:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state, next_state;
    reg [2:0] index;
    reg [31:0] dividend, divisor;
    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd32;

    // Fixed-point division using restoring algorithm
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 3'd0;
            dividend <= 32'd0;
            divisor <= 32'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            cycle_count <= 5'd0;
            done <= 1'b0;
            
            // Initialize result array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        index <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Load current elements
                    if (index < len) begin
                        dividend <= {16'd0, numerator[index]};
                        divisor <= {16'd0, denominator[index]};
                        
                        // Check for division by zero
                        if (divisor == 32'd0) begin
                            result[index] <= 32'h7FFFFFFF;  // Saturate to max
                            index <= index + 3'd1;
                        end else begin
                            // Initialize for division
                            remainder <= dividend;
                            quotient <= 32'd0;
                            
                            // Perform 16-bit division (16 iterations)
                            integer j;
                            for (j = 0; j < 16; j = j + 1) begin
                                remainder <= remainder << 1;
                                quotient <= quotient << 1;
                                
                                if (remainder[31]) begin
                                    remainder[31:0] <= remainder[31:0] + divisor;
                                end else begin
                                    remainder[31:0] <= remainder[31:0] - divisor;
                                    quotient[0] <= 1'b1;
                                end
                            end
                            
                            result[index] <= quotient;
                            index <= index + 3'd1;
                        end
                    end else begin
                        next_state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
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