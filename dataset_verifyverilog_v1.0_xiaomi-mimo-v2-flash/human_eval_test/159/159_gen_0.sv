module carrots_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] number,
    input wire [9:0] need,
    input wire [9:0] remaining,
    output reg [10:0] total,
    output reg [10:0] remaining_after,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CALC    = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;
    reg [10:0] eaten;
    reg [10:0] number_reg, need_reg, remaining_reg;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total <= 11'd0;
            remaining_after <= 11'd0;
            done <= 1'b0;
            eaten <= 11'd0;
            number_reg <= 11'd0;
            need_reg <= 11'd0;
            remaining_reg <= 11'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Register inputs
                        number_reg <= {1'b0, number};
                        need_reg <= {1'b0, need};
                        remaining_reg <= {1'b0, remaining};
                    end
                end
                
                CALC: begin
                    // Compute min(need, remaining)
                    if (need_reg < remaining_reg) begin
                        eaten <= need_reg;
                    end else begin
                        eaten <= remaining_reg;
                    end
                end
                
                FINISH: begin
                    // Compute total = number + eaten
                    total <= number_reg + eaten;
                    // Compute remaining_after = remaining - eaten
                    remaining_after <= remaining_reg - eaten;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC;
                else
                    next_state = IDLE;
            end
            
            CALC: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule