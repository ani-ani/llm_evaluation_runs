module cube_array (
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
    input [3:0] len,
    output reg [15:0] result_0,
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg [15:0] result_3,
    output reg [15:0] result_4,
    output reg [15:0] result_5,
    output reg [15:0] result_6,
    output reg [15:0] result_7,
    output reg done
);

    // State machine definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [3:0] counter;
    reg [1:0] calc_stage;
    reg [7:0] arr_reg [0:7];
    reg [15:0] square_val;
    reg [15:0] temp_result;
    reg [7:0] current_val;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 4'd0;
            calc_stage <= 2'd0;
            result_0 <= 16'd0;
            result_1 <= 16'd0;
            result_2 <= 16'd0;
            result_3 <= 16'd0;
            result_4 <= 16'd0;
            result_5 <= 16'd0;
            result_6 <= 16'd0;
            result_7 <= 16'd0;
            arr_reg[0] <= 8'd0;
            arr_reg[1] <= 8'd0;
            arr_reg[2] <= 8'd0;
            arr_reg[3] <= 8'd0;
            arr_reg[4] <= 8'd0;
            arr_reg[5] <= 8'd0;
            arr_reg[6] <= 8'd0;
            arr_reg[7] <= 8'd0;
            square_val <= 16'd0;
            temp_result <= 16'd0;
            current_val <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    calc_stage <= 2'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Store all inputs in registers
                    arr_reg[0] <= arr_0;
                    arr_reg[1] <= arr_1;
                    arr_reg[2] <= arr_2;
                    arr_reg[3] <= arr_3;
                    arr_reg[4] <= arr_4;
                    arr_reg[5] <= arr_5;
                    arr_reg[6] <= arr_6;
                    arr_reg[7] <= arr_7;
                    counter <= 4'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    if (counter < len) begin
                        case (calc_stage)
                            2'd0: begin
                                // Stage 0: Get current value and compute square
                                current_val <= arr_reg[counter];
                                square_val <= arr_reg[counter] * arr_reg[counter];
                                calc_stage <= 2'd1;
                            end
                            2'd1: begin
                                // Stage 1: Compute cube (square * value)
                                temp_result <= square_val * current_val;
                                calc_stage <= 2'd2;
                            end
                            2'd2: begin
                                // Stage 2: Store result to output port
                                case (counter)
                                    4'd0: result_0 <= temp_result;
                                    4'd1: result_1 <= temp_result;
                                    4'd2: result_2 <= temp_result;
                                    4'd3: result_3 <= temp_result;
                                    4'd4: result_4 <= temp_result;
                                    4'd5: result_5 <= temp_result;
                                    4'd6: result_6 <= temp_result;
                                    4'd7: result_7 <= temp_result;
                                endcase
                                counter <= counter + 4'd1;
                                calc_stage <= 2'd0;
                            end
                            default: calc_stage <= 2'd0;
                        endcase
                    end else begin
                        state <= FINISH;
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