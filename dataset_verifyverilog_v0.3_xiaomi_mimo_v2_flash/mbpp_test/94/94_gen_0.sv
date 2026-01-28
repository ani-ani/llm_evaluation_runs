module find_minimum_tuple (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_second_0,
    input wire [7:0] arr_second_1,
    input wire [7:0] arr_second_2,
    input wire [7:0] arr_second_3,
    input wire [7:0] arr_second_4,
    input wire [7:0] arr_second_5,
    input wire [7:0] arr_second_6,
    input wire [7:0] arr_second_7,
    input wire [7:0] arr_first_0,
    input wire [7:0] arr_first_1,
    input wire [7:0] arr_first_2,
    input wire [7:0] arr_first_3,
    input wire [7:0] arr_first_4,
    input wire [7:0] arr_first_5,
    input wire [7:0] arr_first_6,
    input wire [7:0] arr_first_7,
    input wire [3:0] num_tuples,
    output reg [7:0] result_first,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] INIT    = 4'd1;
    localparam [3:0] COMPARE = 4'd2;
    localparam [3:0] UPDATE  = 4'd3;
    localparam [3:0] DONE    = 4'd4;
    localparam [3:0] DEFAULT_STATE = 4'd5;

    // Registers
    reg [3:0] state;
    reg [3:0] idx;
    reg [7:0] min_second;
    reg [7:0] next_min_second;
    reg [7:0] next_result_first;
    reg [7:0] current_second;
    reg [7:0] current_first;

    // Combinational logic to select current tuple values
    always @(*) begin
        case (idx)
            4'd0: begin
                current_second = arr_second_0;
                current_first = arr_first_0;
            end
            4'd1: begin
                current_second = arr_second_1;
                current_first = arr_first_1;
            end
            4'd2: begin
                current_second = arr_second_2;
                current_first = arr_first_2;
            end
            4'd3: begin
                current_second = arr_second_3;
                current_first = arr_first_3;
            end
            4'd4: begin
                current_second = arr_second_4;
                current_first = arr_first_4;
            end
            4'd5: begin
                current_second = arr_second_5;
                current_first = arr_first_5;
            end
            4'd6: begin
                current_second = arr_second_6;
                current_first = arr_first_6;
            end
            4'd7: begin
                current_second = arr_second_7;
                current_first = arr_first_7;
            end
            default: begin
                current_second = 8'hFF;
                current_first = 8'd0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            min_second <= 8'hFF;
            result_first <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            next_min_second <= 8'hFF;
            next_result_first <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        idx <= 4'd0;
                        min_second <= 8'hFF;
                    end else begin
                        state <= IDLE;
                    end
                end

                INIT: begin
                    if (num_tuples > 4'd0) begin
                        min_second <= current_second;
                        result_first <= current_first;
                        idx <= 4'd1;
                        if (num_tuples > 4'd1) begin
                            state <= COMPARE;
                        end else begin
                            state <= DONE;
                            valid <= 1'b1;
                        end
                    end else begin
                        state <= DONE;
                        valid <= 1'b0;
                    end
                end

                COMPARE: begin
                    if (idx < num_tuples) begin
                        if (current_second < min_second) begin
                            next_min_second <= current_second;
                            next_result_first <= current_first;
                        end else begin
                            next_min_second <= min_second;
                            next_result_first <= result_first;
                        end
                        state <= UPDATE;
                    end else begin
                        state <= DONE;
                        valid <= 1'b1;
                    end
                end

                UPDATE: begin
                    min_second <= next_min_second;
                    result_first <= next_result_first;
                    idx <= idx + 4'd1;
                    state <= COMPARE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                    idx <= 4'd0;
                    min_second <= 8'hFF;
                    result_first <= 8'd0;
                end
            endcase
        end
    end

endmodule