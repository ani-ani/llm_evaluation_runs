module find_Odd_Pair (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [3:0] index;
    reg [15:0] odd_count;
    reg [15:0] even_count;
    reg [7:0] current_element;
    
    always @(*) begin
        case (index)
            4'd0: current_element = arr_0;
            4'd1: current_element = arr_1;
            4'd2: current_element = arr_2;
            4'd3: current_element = arr_3;
            4'd4: current_element = arr_4;
            4'd5: current_element = arr_5;
            4'd6: current_element = arr_6;
            4'd7: current_element = arr_7;
            default: current_element = 8'd0;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            odd_count <= 16'd0;
            even_count <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNT;
                        index <= 4'd0;
                        odd_count <= 16'd0;
                        even_count <= 16'd0;
                    end
                end
                
                COUNT: begin
                    if (index < len) begin
                        if (current_element[0]) begin
                            odd_count <= odd_count + 16'd1;
                        end else begin
                            even_count <= even_count + 16'd1;
                        end
                        index <= index + 4'd1;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    result <= odd_count * even_count;
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