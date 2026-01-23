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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] current_max;
    reg [2:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            current_max <= 8'd0;
            index <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_max <= arr_0;
                        index <= 3'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    case (index)
                        3'd1: current_max <= (arr_1 > current_max) ? arr_1 : current_max;
                        3'd2: current_max <= (arr_2 > current_max) ? arr_2 : current_max;
                        3'd3: current_max <= (arr_3 > current_max) ? arr_3 : current_max;
                        3'd4: current_max <= (arr_4 > current_max) ? arr_4 : current_max;
                        3'd5: current_max <= (arr_5 > current_max) ? arr_5 : current_max;
                        3'd6: current_max <= (arr_6 > current_max) ? arr_6 : current_max;
                        3'd7: current_max <= (arr_7 > current_max) ? arr_7 : current_max;
                        default: current_max <= current_max;
                    endcase
                    
                    index <= index + 3'd1;
                    
                    if (index == 3'd8 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= (number > current_max);
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule