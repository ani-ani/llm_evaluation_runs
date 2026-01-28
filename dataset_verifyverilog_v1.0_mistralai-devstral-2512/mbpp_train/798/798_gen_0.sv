module ArraySumAccumulator(
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
    input wire [7:0] arr_8,
    input wire [7:0] arr_9,
    input wire [7:0] arr_10,
    input wire [7:0] arr_11,
    input wire [7:0] arr_12,
    input wire [7:0] arr_13,
    input wire [7:0] arr_14,
    input wire [7:0] arr_15,
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] FETCH = 2'd1;
    localparam [1:0] ADD   = 2'd2;
    localparam [1:0] DONE  = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] counter;
    reg [15:0] accumulator;
    reg [7:0] current_element;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            counter <= 4'd0;
            accumulator <= 16'd0;
            current_element <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (len == 4'd0) begin
                        next_state = DONE;
                    end else begin
                        next_state = FETCH;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            FETCH: begin
                next_state = ADD;
            end

            ADD: begin
                if (counter == 4'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = FETCH;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
            counter <= 4'd0;
            accumulator <= 16'd0;
            current_element <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        if (len != 4'd0) begin
                            index <= 4'd0;
                            counter <= len;
                            accumulator <= 16'd0;
                        end
                    end
                end

                FETCH: begin
                    case (index)
                        4'd0: current_element <= arr_0;
                        4'd1: current_element <= arr_1;
                        4'd2: current_element <= arr_2;
                        4'd3: current_element <= arr_3;
                        4'd4: current_element <= arr_4;
                        4'd5: current_element <= arr_5;
                        4'd6: current_element <= arr_6;
                        4'd7: current_element <= arr_7;
                        4'd8: current_element <= arr_8;
                        4'd9: current_element <= arr_9;
                        4'd10: current_element <= arr_10;
                        4'd11: current_element <= arr_11;
                        4'd12: current_element <= arr_12;
                        4'd13: current_element <= arr_13;
                        4'd14: current_element <= arr_14;
                        4'd15: current_element <= arr_15;
                        default: current_element <= 8'd0;
                    endcase
                    index <= index + 4'd1;
                end

                ADD: begin
                    accumulator <= accumulator + current_element;
                    counter <= counter - 4'd1;
                end

                DONE: begin
                    result <= accumulator;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule