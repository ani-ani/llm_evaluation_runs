module bit_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    output reg [3:0] result,
    output reg done
);
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] shift_reg;
    reg [3:0] count_reg;
    reg [2:0] bit_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            shift_reg <= 8'd0;
            count_reg <= 4'd0;
            bit_counter <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        shift_reg <= data_in;
                        count_reg <= 4'd0;
                        bit_counter <= 3'd0;
                    end
                end
                
                COUNTING: begin
                    count_reg <= count_reg + {3'd0, shift_reg[0]};
                    shift_reg <= shift_reg >> 1;
                    bit_counter <= bit_counter + 3'd1;
                end
                
                COMPLETE: begin
                    result <= count_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = (start) ? COUNTING : IDLE;
            COUNTING: next_state = (bit_counter == 3'd7) ? COMPLETE : COUNTING;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
endmodule