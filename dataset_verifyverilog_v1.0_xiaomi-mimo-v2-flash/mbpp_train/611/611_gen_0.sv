module column_max(
    input clk,
    input rst_n,
    input start,
    // 8x8 matrix inputs (matrix_row_col)
    input [7:0] matrix_0_0, matrix_0_1, matrix_0_2, matrix_0_3, matrix_0_4, matrix_0_5, matrix_0_6, matrix_0_7,
    input [7:0] matrix_1_0, matrix_1_1, matrix_1_2, matrix_1_3, matrix_1_4, matrix_1_5, matrix_1_6, matrix_1_7,
    input [7:0] matrix_2_0, matrix_2_1, matrix_2_2, matrix_2_3, matrix_2_4, matrix_2_5, matrix_2_6, matrix_2_7,
    input [7:0] matrix_3_0, matrix_3_1, matrix_3_2, matrix_3_3, matrix_3_4, matrix_3_5, matrix_3_6, matrix_3_7,
    input [7:0] matrix_4_0, matrix_4_1, matrix_4_2, matrix_4_3, matrix_4_4, matrix_4_5, matrix_4_6, matrix_4_7,
    input [7:0] matrix_5_0, matrix_5_1, matrix_5_2, matrix_5_3, matrix_5_4, matrix_5_5, matrix_5_6, matrix_5_7,
    input [7:0] matrix_6_0, matrix_6_1, matrix_6_2, matrix_6_3, matrix_6_4, matrix_6_5, matrix_6_6, matrix_6_7,
    input [7:0] matrix_7_0, matrix_7_1, matrix_7_2, matrix_7_3, matrix_7_4, matrix_7_5, matrix_7_6, matrix_7_7,
    input [2:0] col_idx,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [2:0] row_counter;  // 0-7 for rows
    reg [7:0] current_max;
    reg [7:0] current_value;
    reg [7:0] next_max;
    
    // Mux logic to select value based on column index and row counter
    always @(*) begin
        case (row_counter)
            3'd0: begin
                case (col_idx)
                    3'd0: current_value = matrix_0_0;
                    3'd1: current_value = matrix_0_1;
                    3'd2: current_value = matrix_0_2;
                    3'd3: current_value = matrix_0_3;
                    3'd4: current_value = matrix_0_4;
                    3'd5: current_value = matrix_0_5;
                    3'd6: current_value = matrix_0_6;
                    3'd7: current_value = matrix_0_7;
                    default: current_value = 8'd0;
                endcase
            end
            3'd1: begin
                case (col_idx)
                    3'd0: current_value = matrix_1_0;
                    3'd1: current_value = matrix_1_1;
                    3'd2: current_value = matrix_1_2;
                    3'd3: current_value = matrix_1_3;
                    3'd4: current_value = matrix_1_4;
                    3'd5: current_value = matrix_1_5;
                    3'd6: current_value = matrix_1_6;
                    3'd7: current_value = matrix_1_7;
                    default: current_value = 8'd0;
                endcase
            end
            3'd2: begin
                case (col_idx)
                    3'd0: current_value = matrix_2_0;
                    3'd1: current_value = matrix_2_1;
                    3'd2: current_value = matrix_2_2;
                    3'd3: current_value = matrix_2_3;
                    3'd4: current_value = matrix_2_4;
                    3'd5: current_value = matrix_2_5;
                    3'd6: current_value = matrix_2_6;
                    3'd7: current_value = matrix_2_7;
                    default: current_value = 8'd0;
                endcase
            end
            3'd3: begin
                case (col_idx)
                    3'd0: current_value = matrix_3_0;
                    3'd1: current_value = matrix_3_1;
                    3'd2: current_value = matrix_3_2;
                    3'd3: current_value = matrix_3_3;
                    3'd4: current_value = matrix_3_4;
                    3'd5: current_value = matrix_3_5;
                    3'd6: current_value = matrix_3_6;
                    3'd7: current_value = matrix_3_7;
                    default: current_value = 8'd0;
                endcase
            end
            3'd4: begin
                case (col_idx)
                    3'd0: current_value = matrix_4_0;
                    3'd1: current_value = matrix_4_1;
                    3'd2: current_value = matrix_4_2;
                    3'd3: current_value = matrix_4_3;
                    3'd4: current_value = matrix_4_4;
                    3'd5: current_value = matrix_4_5;
                    3'd6: current_value = matrix_4_6;
                    3'd7: current_value = matrix_4_7;
                    default: current_value = 8'd0;
                endcase
            end
            3'd5: begin
                case (col_idx)
                    3'd0: current_value = matrix_5_0;
                    3'd1: current_value = matrix_5_1;
                    3'd2: current_value = matrix_5_2;
                    3'd3: current_value = matrix_5_3;
                    3'd4: current_value = matrix_5_4;
                    3'd5: current_value = matrix_5_5;
                    3'd6: current_value = matrix_5_6;
                    3'd7: current_value = matrix_5_7;
                    default: current_value = 8'd0;
                endcase
            end
            3'd6: begin
                case (col_idx)
                    3'd0: current_value = matrix_6_0;
                    3'd1: current_value = matrix_6_1;
                    3'd2: current_value = matrix_6_2;
                    3'd3: current_value = matrix_6_3;
                    3'd4: current_value = matrix_6_4;
                    3'd5: current_value = matrix_6_5;
                    3'd6: current_value = matrix_6_6;
                    3'd7: current_value = matrix_6_7;
                    default: current_value = 8'd0;
                endcase
            end
            3'd7: begin
                case (col_idx)
                    3'd0: current_value = matrix_7_0;
                    3'd1: current_value = matrix_7_1;
                    3'd2: current_value = matrix_7_2;
                    3'd3: current_value = matrix_7_3;
                    3'd4: current_value = matrix_7_4;
                    3'd5: current_value = matrix_7_5;
                    3'd6: current_value = matrix_7_6;
                    3'd7: current_value = matrix_7_7;
                    default: current_value = 8'd0;
                endcase
            end
            default: current_value = 8'd0;
        endcase
        
        // Compare and determine next max
        if (current_value > current_max) begin
            next_max = current_value;
        end else begin
            next_max = current_max;
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            row_counter <= 3'd0;
            current_max <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    row_counter <= 3'd0;
                    current_max <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    // Update max value for current row
                    current_max <= next_max;
                    
                    if (row_counter < 3'd7) begin
                        row_counter <= row_counter + 3'd1;
                        state <= PROCESS;
                    end else begin
                        // All rows processed
                        result <= next_max;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 8'd0;
                    done <= 1'b0;
                    row_counter <= 3'd0;
                    current_max <= 8'd0;
                end
            endcase
        end
    end
endmodule