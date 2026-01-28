module deg_to_rad (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] degree_in,
    output reg signed [31:0] radian_out,
    output reg done
);

    // Constants in Q16.16 format
    localparam [31:0] PI_Q16_16 = 32'h3243F6A8;
    localparam [31:0] INV_180_Q16_16 = 32'h0002E14F;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] MULT1 = 3'd1;
    localparam [2:0] MULT2 = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;

    // Pipeline registers
    reg signed [47:0] mult1_result;  // 16-bit * 32-bit = 48-bit
    reg signed [47:0] mult1_reg;
    reg signed [63:0] mult2_result;  // 32-bit * 32-bit = 64-bit
    reg signed [31:0] radian_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            radian_out <= 32'd0;
            mult1_reg <= 48'd0;
            mult2_result <= 64'd0;
            radian_reg <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Pipeline stage 1: degree * PI
                        mult1_reg <= $signed(degree_in) * $signed(PI_Q16_16);
                    end
                end
                
                MULT1: begin
                    // Pipeline stage 2: shift and multiply by 1/180
                    mult2_result <= $signed(mult1_reg[47:16]) * $signed(INV_180_Q16_16);
                end
                
                MULT2: begin
                    // Pipeline stage 3: shift final result
                    radian_reg <= mult2_result[47:16];
                end
                
                FINISH: begin
                    radian_out <= radian_reg;
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = MULT1;
            end
            MULT1: begin
                next_state = MULT2;
            end
            MULT2: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule