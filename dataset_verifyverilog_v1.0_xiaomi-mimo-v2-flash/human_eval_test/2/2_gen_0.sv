module ExtractFractionalPart(
    input clk,
    input rst_n,
    input start,
    input [31:0] fixed_in,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EXTRACT = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [15:0] fractional_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            fractional_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= EXTRACT;
                        // Extract fractional part (lower 16 bits)
                        fractional_reg <= fixed_in[15:0];
                    end
                end
                
                EXTRACT: begin
                    // Output the extracted fractional part
                    result <= fractional_reg;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule