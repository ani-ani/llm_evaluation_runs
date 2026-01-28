module OppositeSignDetector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] x,
    input wire signed [31:0] y,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [31:0] x_reg, y_reg;
    reg result_reg;
    
    // Combinational logic for computation
    wire xor_val;
    assign xor_val = x_reg[31] ^ y_reg[31];
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_reg <= 32'd0;
            y_reg <= 32'd0;
            result_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= x;
                        y_reg <= y;
                    end
                end
                COMPUTE: begin
                    result_reg <= xor_val;
                end
                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
                default: begin
                    // Initialize
                end
            endcase
        end
    end

endmodule