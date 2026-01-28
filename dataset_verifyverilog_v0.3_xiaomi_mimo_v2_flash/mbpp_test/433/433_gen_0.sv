module check_greater(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [7:0] number,
    output reg result,
    output reg done
);

    parameter ARRAY_SIZE = 8;
    localparam [3:0] MAX_CYCLES = 4'd9;
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FIND_MAX = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [3:0] cycle_count;
    reg [7:0] current_max;
    reg [2:0] index;
    reg [7:0] temp_max;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            current_max <= 8'd0;
            index <= 3'd0;
            temp_max <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    index <= 3'd0;
                    if (start) begin
                        state <= FIND_MAX;
                        current_max <= arr_0;
                        index <= 3'd1;
                        cycle_count <= 4'd1;
                    end
                end
                
                FIND_MAX: begin
                    cycle_count <= cycle_count + 4'd1;
                    case (index)
                        3'd1: temp_max <= arr_1;
                        3'd2: temp_max <= arr_2;
                        3'd3: temp_max <= arr_3;
                        3'd4: temp_max <= arr_4;
                        3'd5: temp_max <= arr_5;
                        3'd6: temp_max <= arr_6;
                        3'd7: temp_max <= arr_7;
                        default: temp_max <= current_max;
                    endcase
                    
                    if (cycle_count < ARRAY_SIZE) begin
                        index <= index + 3'd1;
                    end else begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    if (temp_max > current_max) begin
                        current_max <= temp_max;
                    end
                    result <= (number > current_max);
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
    
    always @(*) begin
        if (state == FIND_MAX && cycle_count < ARRAY_SIZE) begin
            case (index)
                3'd1: current_max = arr_1;
                3'd2: current_max = arr_2;
                3'd3: current_max = arr_3;
                3'd4: current_max = arr_4;
                3'd5: current_max = arr_5;
                3'd6: current_max = arr_6;
                3'd7: current_max = arr_7;
                default: current_max = current_max;
            endcase
        end
    end

endmodule