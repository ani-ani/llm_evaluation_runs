module tuple_to_int (
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [3:0] arr_0,
    input [3:0] arr_1,
    input [3:0] arr_2,
    input [3:0] arr_3,
    input [3:0] arr_4,
    input [3:0] arr_5,
    input [3:0] arr_6,
    input [3:0] arr_7,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam IDLE = 1'b0;
    localparam WORKING = 1'b1;
    
    reg state;
    reg [3:0] idx;
    reg [31:0] accumulator;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            idx <= 4'd0;
            accumulator <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= WORKING;
                        idx <= 4'd0;
                        accumulator <= 32'd0;
                    end
                end
                
                WORKING: begin
                    if (idx < len && idx < 4'd8) begin
                        case (idx)
                            4'd0: accumulator <= (accumulator * 32'd10) + arr_0;
                            4'd1: accumulator <= (accumulator * 32'd10) + arr_1;
                            4'd2: accumulator <= (accumulator * 32'd10) + arr_2;
                            4'd3: accumulator <= (accumulator * 32'd10) + arr_3;
                            4'd4: accumulator <= (accumulator * 32'd10) + arr_4;
                            4'd5: accumulator <= (accumulator * 32'd10) + arr_5;
                            4'd6: accumulator <= (accumulator * 32'd10) + arr_6;
                            4'd7: accumulator <= (accumulator * 32'd10) + arr_7;
                            default: accumulator <= accumulator;
                        endcase
                        idx <= idx + 4'd1;
                    end else begin
                        result <= accumulator;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule