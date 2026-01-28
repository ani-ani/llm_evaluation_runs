module largest_neg(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    output reg [7:0] result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [2:0] index;
    reg signed [7:0] current_max;
    reg signed [7:0] arr_reg_0;
    reg signed [7:0] arr_reg_1;
    reg signed [7:0] arr_reg_2;
    reg signed [7:0] arr_reg_3;
    reg signed [7:0] arr_reg_4;
    reg signed [7:0] arr_reg_5;
    reg [2:0] arr_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            index <= 3'd0;
            current_max <= 8'sd0;
            arr_reg_0 <= 8'sd0;
            arr_reg_1 <= 8'sd0;
            arr_reg_2 <= 8'sd0;
            arr_reg_3 <= 8'sd0;
            arr_reg_4 <= 8'sd0;
            arr_reg_5 <= 8'sd0;
            arr_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        arr_reg_0 <= $signed(arr_0);
                        arr_reg_1 <= $signed(arr_1);
                        arr_reg_2 <= $signed(arr_2);
                        arr_reg_3 <= $signed(arr_3);
                        arr_reg_4 <= $signed(arr_4);
                        arr_reg_5 <= $signed(arr_5);
                        current_max <= $signed(arr_0);
                        index <= 3'd1;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (index < 6) begin
                        case (index)
                            3'd1: begin
                                if (arr_reg_1 < current_max)
                                    current_max <= arr_reg_1;
                            end
                            3'd2: begin
                                if (arr_reg_2 < current_max)
                                    current_max <= arr_reg_2;
                            end
                            3'd3: begin
                                if (arr_reg_3 < current_max)
                                    current_max <= arr_reg_3;
                            end
                            3'd4: begin
                                if (arr_reg_4 < current_max)
                                    current_max <= arr_reg_4;
                            end
                            3'd5: begin
                                if (arr_reg_5 < current_max)
                                    current_max <= arr_reg_5;
                            end
                            default: current_max <= current_max;
                        endcase
                        index <= index + 1'b1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= current_max;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule