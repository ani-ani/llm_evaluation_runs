module tuple_list_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple_data,
    output reg [3:0] result,
    output reg done
);

    reg [3:0] count_reg;
    reg [2:0] index;
    reg [1:0] state;
    reg [2:0] index_next;
    reg [3:0] count_reg_next;

    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COUNTING = 2'b01;
    localparam [1:0] COMPLETE = 2'b10;

    always @(*) begin
        index_next = index;
        count_reg_next = count_reg;
        
        case (state)
            IDLE: begin
                count_reg_next = 4'd0;
                index_next = 3'd0;
            end
            COUNTING: begin
                if (tuple_data[index]) begin
                    count_reg_next = count_reg + 1'b1;
                end
                if (index < 3'd7) begin
                    index_next = index + 1'b1;
                end
            end
            COMPLETE: begin
                count_reg_next = count_reg;
                index_next = index;
            end
            default: begin
                count_reg_next = 4'd0;
                index_next = 3'd0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'b0;
            done <= 1'b0;
            state <= IDLE;
            count_reg <= 4'b0;
            index <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNTING;
                    end
                end
                COUNTING: begin
                    if (index >= 3'd7) begin
                        state <= COMPLETE;
                    end
                end
                COMPLETE: begin
                    result <= count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
            
            count_reg <= count_reg_next;
            index <= index_next;
        end
    end

endmodule