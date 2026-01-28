module string_length_calculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] string_data_0,
    input [7:0] string_data_1,
    input [7:0] string_data_2,
    input [7:0] string_data_3,
    input [7:0] string_data_4,
    input [7:0] string_data_5,
    input [7:0] string_data_6,
    input [7:0] string_data_7,
    input [7:0] string_data_8,
    input [7:0] string_data_9,
    input [7:0] string_data_10,
    input [7:0] string_data_11,
    input [7:0] string_data_12,
    input [7:0] string_data_13,
    input [7:0] string_data_14,
    input [7:0] string_data_15,
    output reg [5:0] length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [5:0] length_reg;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            length_reg <= 6'd0;
            length <= 6'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCANNING;
                    index = 4'd0;
                    length_reg = 6'd0;
                    done = 1'b0;
                end else begin
                    done = 1'b0;
                end
            end

            SCANNING: begin
                case (index)
                    4'd0: begin
                        if (string_data_0 == 8'd0) begin
                            length_reg = 6'd0;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd1;
                        end
                    end
                    4'd1: begin
                        if (string_data_1 == 8'd0) begin
                            length_reg = 6'd1;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd2;
                        end
                    end
                    4'd2: begin
                        if (string_data_2 == 8'd0) begin
                            length_reg = 6'd2;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd3;
                        end
                    end
                    4'd3: begin
                        if (string_data_3 == 8'd0) begin
                            length_reg = 6'd3;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd4;
                        end
                    end
                    4'd4: begin
                        if (string_data_4 == 8'd0) begin
                            length_reg = 6'd4;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd5;
                        end
                    end
                    4'd5: begin
                        if (string_data_5 == 8'd0) begin
                            length_reg = 6'd5;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd6;
                        end
                    end
                    4'd6: begin
                        if (string_data_6 == 8'd0) begin
                            length_reg = 6'd6;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd7;
                        end
                    end
                    4'd7: begin
                        if (string_data_7 == 8'd0) begin
                            length_reg = 6'd7;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd8;
                        end
                    end
                    4'd8: begin
                        if (string_data_8 == 8'd0) begin
                            length_reg = 6'd8;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd9;
                        end
                    end
                    4'd9: begin
                        if (string_data_9 == 8'd0) begin
                            length_reg = 6'd9;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd10;
                        end
                    end
                    4'd10: begin
                        if (string_data_10 == 8'd0) begin
                            length_reg = 6'd10;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd11;
                        end
                    end
                    4'd11: begin
                        if (string_data_11 == 8'd0) begin
                            length_reg = 6'd11;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd12;
                        end
                    end
                    4'd12: begin
                        if (string_data_12 == 8'd0) begin
                            length_reg = 6'd12;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd13;
                        end
                    end
                    4'd13: begin
                        if (string_data_13 == 8'd0) begin
                            length_reg = 6'd13;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd14;
                        end
                    end
                    4'd14: begin
                        if (string_data_14 == 8'd0) begin
                            length_reg = 6'd14;
                            next_state = DONE_STATE;
                        end else begin
                            index = 4'd15;
                        end
                    end
                    4'd15: begin
                        if (string_data_15 == 8'd0) begin
                            length_reg = 6'd15;
                            next_state = DONE_STATE;
                        end else begin
                            length_reg = 6'd16;
                            next_state = DONE_STATE;
                        end
                    end
                    default: begin
                        length_reg = 6'd16;
                        next_state = DONE_STATE;
                    end
                endcase
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
            end
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            length <= 6'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    length <= 6'd0;
                    done <= 1'b0;
                end
                SCANNING: begin
                    done <= 1'b0;
                end
                DONE_STATE: begin
                    length <= length_reg;
                    done <= 1'b1;
                end
                default: begin
                    length <= 6'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule