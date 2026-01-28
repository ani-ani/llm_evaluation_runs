module SumEvenOddIndices(
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
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [2:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        index <= 3'd0;
                        result <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if index is odd and element is even
                    if (index[0] == 1'b1) begin
                        case (index)
                            3'd1: if (arr_1[0] == 1'b0) result <= result + arr_1;
                            3'd3: if (arr_3[0] == 1'b0) result <= result + arr_3;
                            3'd5: if (arr_5[0] == 1'b0) result <= result + arr_5;
                            3'd7: if (arr_7[0] == 1'b0) result <= result + arr_7;
                            default: ;
                        endcase
                    end
                    
                    // Move to next index or finish
                    if (index == 3'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 3'd1;
                    end
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