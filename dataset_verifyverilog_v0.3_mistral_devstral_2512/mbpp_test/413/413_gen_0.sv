module ExtractNthElement(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] field_select,
    input wire [7:0] name_0_0, input wire [7:0] name_0_1, input wire [7:0] name_0_2, input wire [7:0] name_0_3,
    input wire [7:0] name_0_4, input wire [7:0] name_0_5, input wire [7:0] name_0_6, input wire [7:0] name_0_7,
    input wire [7:0] name_0_8, input wire [7:0] name_0_9, input wire [7:0] name_0_10, input wire [7:0] name_0_11,
    input wire [7:0] name_0_12, input wire [7:0] name_0_13, input wire [7:0] name_0_14, input wire [7:0] name_0_15,
    input wire [7:0] name_1_0, input wire [7:0] name_1_1, input wire [7:0] name_1_2, input wire [7:0] name_1_3,
    input wire [7:0] name_1_4, input wire [7:0] name_1_5, input wire [7:0] name_1_6, input wire [7:0] name_1_7,
    input wire [7:0] name_1_8, input wire [7:0] name_1_9, input wire [7:0] name_1_10, input wire [7:0] name_1_11,
    input wire [7:0] name_1_12, input wire [7:0] name_1_13, input wire [7:0] name_1_14, input wire [7:0] name_1_15,
    input wire [7:0] name_2_0, input wire [7:0] name_2_1, input wire [7:0] name_2_2, input wire [7:0] name_2_3,
    input wire [7:0] name_2_4, input wire [7:0] name_2_5, input wire [7:0] name_2_6, input wire [7:0] name_2_7,
    input wire [7:0] name_2_8, input wire [7:0] name_2_9, input wire [7:0] name_2_10, input wire [7:0] name_2_11,
    input wire [7:0] name_2_12, input wire [7:0] name_2_13, input wire [7:0] name_2_14, input wire [7:0] name_2_15,
    input wire [7:0] name_3_0, input wire [7:0] name_3_1, input wire [7:0] name_3_2, input wire [7:0] name_3_3,
    input wire [7:0] name_3_4, input wire [7:0] name_3_5, input wire [7:0] name_3_6, input wire [7:0] name_3_7,
    input wire [7:0] name_3_8, input wire [7:0] name_3_9, input wire [7:0] name_3_10, input wire [7:0] name_3_11,
    input wire [7:0] name_3_12, input wire [7:0] name_3_13, input wire [7:0] name_3_14, input wire [7:0] name_3_15,
    input wire [7:0] score1_0, input wire [7:0] score1_1, input wire [7:0] score1_2, input wire [7:0] score1_3,
    input wire [7:0] score2_0, input wire [7:0] score2_1, input wire [7:0] score2_2, input wire [7:0] score2_3,
    output reg [7:0] result_0, output reg [7:0] result_1, output reg [7:0] result_2, output reg [7:0] result_3,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] WORK = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= WORK;
                    end
                end
                
                WORK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    case (field_select)
                        2'd0: begin
                            result_0 <= name_0_0;
                            result_1 <= name_1_0;
                            result_2 <= name_2_0;
                            result_3 <= name_3_0;
                        end
                        2'd1: begin
                            result_0 <= score1_0;
                            result_1 <= score1_1;
                            result_2 <= score1_2;
                            result_3 <= score1_3;
                        end
                        2'd2: begin
                            result_0 <= score2_0;
                            result_1 <= score2_1;
                            result_2 <= score2_2;
                            result_3 <= score2_3;
                        end
                        default: begin
                            result_0 <= 8'd0;
                            result_1 <= 8'd0;
                            result_2 <= 8'd0;
                            result_3 <= 8'd0;
                        end
                    endcase
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
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