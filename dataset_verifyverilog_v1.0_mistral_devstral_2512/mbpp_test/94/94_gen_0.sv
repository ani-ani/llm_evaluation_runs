module find_minimum_tuple (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_second_0,  // Second value of tuple 0
    input wire [7:0] arr_second_1,  // Second value of tuple 1
    input wire [7:0] arr_second_2,  // Second value of tuple 2
    input wire [7:0] arr_second_3,  // Second value of tuple 3
    input wire [7:0] arr_second_4,  // Second value of tuple 4
    input wire [7:0] arr_second_5,  // Second value of tuple 5
    input wire [7:0] arr_second_6,  // Second value of tuple 6
    input wire [7:0] arr_second_7,  // Second value of tuple 7
    input wire [7:0] arr_first_0,   // First value of tuple 0 (identifier)
    input wire [7:0] arr_first_1,   // First value of tuple 1
    input wire [7:0] arr_first_2,   // First value of tuple 2
    input wire [7:0] arr_first_3,   // First value of tuple 3
    input wire [7:0] arr_first_4,   // First value of tuple 4
    input wire [7:0] arr_first_5,   // First value of tuple 5
    input wire [7:0] arr_first_6,   // First value of tuple 6
    input wire [7:0] arr_first_7,   // First value of tuple 7
    input wire [3:0] num_tuples,    // Number of valid tuples (1-8)
    output reg [7:0] result_first,
    output reg done,
    output reg valid
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [2:0] idx;
    reg [7:0] min_second;
    reg [7:0] current_first;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 3'd0;
            min_second <= 8'd0;
            current_first <= 8'd0;
            result_first <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        idx <= 3'd0;
                        min_second <= 8'hFF;
                    end
                end

                INIT: begin
                    // Initialize with first tuple
                    if (num_tuples > 0) begin
                        case (idx)
                            3'd0: begin
                                min_second <= arr_second_0;
                                current_first <= arr_first_0;
                            end
                            3'd1: begin
                                min_second <= arr_second_1;
                                current_first <= arr_first_1;
                            end
                            3'd2: begin
                                min_second <= arr_second_2;
                                current_first <= arr_first_2;
                            end
                            3'd3: begin
                                min_second <= arr_second_3;
                                current_first <= arr_first_3;
                            end
                            3'd4: begin
                                min_second <= arr_second_4;
                                current_first <= arr_first_4;
                            end
                            3'd5: begin
                                min_second <= arr_second_5;
                                current_first <= arr_first_5;
                            end
                            3'd6: begin
                                min_second <= arr_second_6;
                                current_first <= arr_first_6;
                            end
                            3'd7: begin
                                min_second <= arr_second_7;
                                current_first <= arr_first_7;
                            end
                        endcase
                        idx <= idx + 3'd1;
                        if (idx >= num_tuples) begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                        valid <= 1'b0;
                    end
                end

                COMPARE: begin
                    // Compare current tuple with minimum
                    if (idx < num_tuples) begin
                        case (idx)
                            3'd0: begin
                                if (arr_second_0 < min_second) begin
                                    min_second <= arr_second_0;
                                    current_first <= arr_first_0;
                                end
                            end
                            3'd1: begin
                                if (arr_second_1 < min_second) begin
                                    min_second <= arr_second_1;
                                    current_first <= arr_first_1;
                                end
                            end
                            3'd2: begin
                                if (arr_second_2 < min_second) begin
                                    min_second <= arr_second_2;
                                    current_first <= arr_first_2;
                                end
                            end
                            3'd3: begin
                                if (arr_second_3 < min_second) begin
                                    min_second <= arr_second_3;
                                    current_first <= arr_first_3;
                                end
                            end
                            3'd4: begin
                                if (arr_second_4 < min_second) begin
                                    min_second <= arr_second_4;
                                    current_first <= arr_first_4;
                                end
                            end
                            3'd5: begin
                                if (arr_second_5 < min_second) begin
                                    min_second <= arr_second_5;
                                    current_first <= arr_first_5;
                                end
                            end
                            3'd6: begin
                                if (arr_second_6 < min_second) begin
                                    min_second <= arr_second_6;
                                    current_first <= arr_first_6;
                                end
                            end
                            3'd7: begin
                                if (arr_second_7 < min_second) begin
                                    min_second <= arr_second_7;
                                    current_first <= arr_first_7;
                                end
                            end
                        endcase
                        idx <= idx + 3'd1;
                        if (idx >= num_tuples) begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    result_first <= current_first;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule