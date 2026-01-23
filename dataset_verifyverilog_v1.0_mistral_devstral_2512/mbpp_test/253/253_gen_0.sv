module count_integer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [1:0] index;
    reg [3:0] count_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 2'd0;
            count_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 2'd0;
                    count_reg <= 4'd0;
                    if (start) begin
                        state <= COUNT;
                    end
                end
                
                COUNT: begin
                    // Check current element
                    if (index == 2'd0) begin
                        if (arr_0 < 8'd32 || arr_0 > 8'd126)
                            count_reg <= count_reg + 4'd1;
                    end else if (index == 2'd1) begin
                        if (arr_1 < 8'd32 || arr_1 > 8'd126)
                            count_reg <= count_reg + 4'd1;
                    end else if (index == 2'd2) begin
                        if (arr_2 < 8'd32 || arr_2 > 8'd126)
                            count_reg <= count_reg + 4'd1;
                    end else if (index == 2'd3) begin
                        if (arr_3 < 8'd32 || arr_3 > 8'd126)
                            count_reg <= count_reg + 4'd1;
                    end
                    
                    if (index < 2'd3) begin
                        index <= index + 2'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule