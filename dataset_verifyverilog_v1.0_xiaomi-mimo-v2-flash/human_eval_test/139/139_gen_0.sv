module brazilian_factorial (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [31:0] result,
    output reg overflow,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // State register
    reg [1:0] state;

    // Combinational lookup table for factorials 1! to 12!
    // Using separate signals for each factorial value
    reg [31:0] fact_value;
    always @(*) begin
        case (n)
            8'd1:   fact_value = 32'd1;
            8'd2:   fact_value = 32'd2;
            8'd3:   fact_value = 32'd6;
            8'd4:   fact_value = 32'd24;
            8'd5:   fact_value = 32'd120;
            8'd6:   fact_value = 32'd720;
            8'd7:   fact_value = 32'd5040;
            8'd8:   fact_value = 32'd40320;
            8'd9:   fact_value = 32'd362880;
            8'd10:  fact_value = 32'd3628800;
            8'd11:  fact_value = 32'd39916800;
            8'd12:  fact_value = 32'd479001600;
            default: fact_value = 32'd0;
        endcase
    end

    // Sequential logic
    reg [31:0] accum;
    reg [7:0] counter;
    reg overflow_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            overflow <= 1'b0;
            done <= 1'b0;
            accum <= 32'd0;
            counter <= 8'd0;
            overflow_temp <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    overflow_temp <= 1'b0;
                    result <= 32'd0;
                    
                    if (start) begin
                        if (n == 8'd0) begin
                            result <= 32'd1;
                            done <= 1'b1;
                            state <= DONE;
                        end else if (n > 8'd12) begin
                            overflow_temp <= 1'b1;
                            result <= 32'd0;
                            state <= DONE;
                        end else begin
                            // n <= 12: compute factorial product
                            accum <= 32'd1;
                            counter <= n;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Multiply accum by fact_value of current counter
                    // Check for overflow before multiplication
                    if (fact_value != 32'd0 && accum > (32'hFFFFFFFF / fact_value)) begin
                        overflow_temp <= 1'b1;
                        result <= 32'd0;
                        state <= DONE;
                    end else begin
                        accum <= accum * fact_value;
                        
                        if (counter == 8'd1) begin
                            result <= accum * fact_value;
                            state <= DONE;
                        end else begin
                            counter <= counter - 8'd1;
                            // Update n for next lookup (counter-1)
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    overflow <= overflow_temp;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    overflow <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule