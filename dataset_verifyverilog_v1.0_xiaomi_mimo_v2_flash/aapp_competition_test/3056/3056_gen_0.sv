module WalkSum #(
    parameter MAX_LEN = 16,
    parameter DATA_WIDTH = 128
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [MAX_LEN*2-1:0] string_packed,
    input wire [$clog2(MAX_LEN+1)-1:0] length,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] PROCESS = 2'b01;
    localparam [1:0] DONE = 2'b10;
    
    reg [1:0] state, next_state;
    reg [$clog2(MAX_LEN):0] index, next_index;
    reg [DATA_WIDTH-1:0] count, next_count;
    reg [DATA_WIDTH-1:0] sum, next_sum;
    reg done_reg;
    
    wire [1:0] current_char;
    assign current_char = string_packed[index*2 +: 2];
    
    always @(*) begin
        next_state = state;
        next_index = index;
        next_count = count;
        next_sum = sum;
        done_reg = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_index = 0;
                    next_count = 1;
                    next_sum = 1;
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                case (current_char)
                    2'b00: begin
                        next_sum = sum * 2;
                        next_count = count;
                    end
                    2'b01: begin
                        next_sum = sum * 2 + count;
                        next_count = count;
                    end
                    2'b10: begin
                        next_sum = sum;
                        next_count = count;
                    end
                    2'b11: begin
                        next_sum = sum * 5 + count;
                        next_count = count * 3;
                    end
                    default: begin
                        next_sum = sum;
                        next_count = count;
                    end
                endcase
                next_index = index + 1;
                if (index + 1 == length) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                done_reg = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 0;
            count <= 0;
            sum <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            index <= next_index;
            count <= next_count;
            sum <= next_sum;
            done <= done_reg;
            
            if (state == DONE) begin
                result <= sum;
            end
        end
    end
endmodule