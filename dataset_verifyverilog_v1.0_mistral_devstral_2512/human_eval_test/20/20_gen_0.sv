module find_closest_elements(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr_0,
    input [15:0] arr_1,
    input [15:0] arr_2,
    input [15:0] arr_3,
    input [15:0] arr_4,
    input [15:0] arr_5,
    output reg [15:0] min_val,
    output reg [15:0] max_val,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] LOAD      = 4'd1;
    localparam [3:0] SORT_0    = 4'd2;
    localparam [3:0] SORT_1    = 4'd3;
    localparam [3:0] SORT_2    = 4'd4;
    localparam [3:0] SORT_3    = 4'd5;
    localparam [3:0] SORT_4    = 4'd6;
    localparam [3:0] DIFF_CALC = 4'd7;
    localparam [3:0] DONE      = 4'd8;

    reg [3:0] state;
    reg [15:0] arr [0:5];
    reg [15:0] diff [0:4];
    reg [15:0] min_diff;
    reg [2:0] min_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_val <= 16'd0;
            max_val <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (integer i = 0; i < 6; i = i + 1) begin
                arr[i] <= 16'd0;
            end
            for (integer i = 0; i < 5; i = i + 1) begin
                diff[i] <= 16'd0;
            end
            min_diff <= 16'd0;
            min_index <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    arr[0] <= arr_0;
                    arr[1] <= arr_1;
                    arr[2] <= arr_2;
                    arr[3] <= arr_3;
                    arr[4] <= arr_4;
                    arr[5] <= arr_5;
                    state <= SORT_0;
                end

                SORT_0: begin
                    // Pass 1: (0,1), (1,2), (2,3), (3,4), (4,5)
                    if (arr[1] < arr[0]) begin
                        arr[0] <= arr[1];
                        arr[1] <= arr_0;
                    end
                    if (arr[2] < arr[1]) begin
                        arr[1] <= arr[2];
                        arr[2] <= arr_1;
                    end
                    if (arr[3] < arr[2]) begin
                        arr[2] <= arr[3];
                        arr[3] <= arr_2;
                    end
                    if (arr[4] < arr[3]) begin
                        arr[3] <= arr[4];
                        arr[4] <= arr_3;
                    end
                    if (arr[5] < arr[4]) begin
                        arr[4] <= arr[5];
                        arr[5] <= arr_4;
                    end
                    state <= SORT_1;
                end

                SORT_1: begin
                    // Pass 2: (0,1), (1,2), (2,3), (3,4)
                    if (arr[1] < arr[0]) begin
                        arr[0] <= arr[1];
                        arr[1] <= arr_0;
                    end
                    if (arr[2] < arr[1]) begin
                        arr[1] <= arr[2];
                        arr[2] <= arr_1;
                    end
                    if (arr[3] < arr[2]) begin
                        arr[2] <= arr[3];
                        arr[3] <= arr_2;
                    end
                    if (arr[4] < arr[3]) begin
                        arr[3] <= arr[4];
                        arr[4] <= arr_3;
                    end
                    state <= SORT_2;
                end

                SORT_2: begin
                    // Pass 3: (0,1), (1,2), (2,3)
                    if (arr[1] < arr[0]) begin
                        arr[0] <= arr[1];
                        arr[1] <= arr_0;
                    end
                    if (arr[2] < arr[1]) begin
                        arr[1] <= arr[2];
                        arr[2] <= arr_1;
                    end
                    if (arr[3] < arr[2]) begin
                        arr[2] <= arr[3];
                        arr[3] <= arr_2;
                    end
                    state <= SORT_3;
                end

                SORT_3: begin
                    // Pass 4: (0,1), (1,2)
                    if (arr[1] < arr[0]) begin
                        arr[0] <= arr[1];
                        arr[1] <= arr_0;
                    end
                    if (arr[2] < arr[1]) begin
                        arr[1] <= arr[2];
                        arr[2] <= arr_1;
                    end
                    state <= SORT_4;
                end

                SORT_4: begin
                    // Pass 5: (0,1)
                    if (arr[1] < arr[0]) begin
                        arr[0] <= arr[1];
                        arr[1] <= arr_0;
                    end
                    state <= DIFF_CALC;
                end

                DIFF_CALC: begin
                    // Calculate differences
                    diff[0] <= arr[1] - arr[0];
                    diff[1] <= arr[2] - arr[1];
                    diff[2] <= arr[3] - arr[2];
                    diff[3] <= arr[4] - arr[3];
                    diff[4] <= arr[5] - arr[4];

                    // Find minimum difference
                    min_diff <= diff[0];
                    min_index <= 3'd0;
                    if (diff[1] < min_diff) begin
                        min_diff <= diff[1];
                        min_index <= 3'd1;
                    end
                    if (diff[2] < min_diff) begin
                        min_diff <= diff[2];
                        min_index <= 3'd2;
                    end
                    if (diff[3] < min_diff) begin
                        min_diff <= diff[3];
                        min_index <= 3'd3;
                    end
                    if (diff[4] < min_diff) begin
                        min_diff <= diff[4];
                        min_index <= 3'd4;
                    end

                    // Set output values
                    case (min_index)
                        3'd0: begin
                            min_val <= arr[0];
                            max_val <= arr[1];
                        end
                        3'd1: begin
                            min_val <= arr[1];
                            max_val <= arr[2];
                        end
                        3'd2: begin
                            min_val <= arr[2];
                            max_val <= arr[3];
                        end
                        3'd3: begin
                            min_val <= arr[3];
                            max_val <= arr[4];
                        end
                        3'd4: begin
                            min_val <= arr[4];
                            max_val <= arr[5];
                        end
                        default: begin
                            min_val <= 16'd0;
                            max_val <= 16'd0;
                        end
                    endcase

                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule