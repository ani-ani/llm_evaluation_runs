module sort_third(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input wire [7:0] arr_8, arr_9, arr_10, arr_11, arr_12, arr_13, arr_14, arr_15,
    input wire [3:0] length,
    output reg [7:0] result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7,
    output reg [7:0] result_8, result_9, result_10, result_11, result_12, result_13, result_14, result_15,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] temp_array [0:15];
    reg [3:0] pass_counter;
    reg [3:0] swap_counter;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            pass_counter <= 4'd0;
            swap_counter <= 4'd0;
            cycle_count <= 8'd0;

            // Initialize result and temp_array
            result_0 <= 8'd0; result_1 <= 8'd0; result_2 <= 8'd0; result_3 <= 8'd0;
            result_4 <= 8'd0; result_5 <= 8'd0; result_6 <= 8'd0; result_7 <= 8'd0;
            result_8 <= 8'd0; result_9 <= 8'd0; result_10 <= 8'd0; result_11 <= 8'd0;
            result_12 <= 8'd0; result_13 <= 8'd0; result_14 <= 8'd0; result_15 <= 8'd0;

            temp_array[0] <= 8'd0; temp_array[1] <= 8'd0; temp_array[2] <= 8'd0; temp_array[3] <= 8'd0;
            temp_array[4] <= 8'd0; temp_array[5] <= 8'd0; temp_array[6] <= 8'd0; temp_array[7] <= 8'd0;
            temp_array[8] <= 8'd0; temp_array[9] <= 8'd0; temp_array[10] <= 8'd0; temp_array[11] <= 8'd0;
            temp_array[12] <= 8'd0; temp_array[13] <= 8'd0; temp_array[14] <= 8'd0; temp_array[15] <= 8'd0;
        end else begin
            state <= next_state;

            // State machine
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Latch input array
                        temp_array[0] <= arr_0; temp_array[1] <= arr_1; temp_array[2] <= arr_2; temp_array[3] <= arr_3;
                        temp_array[4] <= arr_4; temp_array[5] <= arr_5; temp_array[6] <= arr_6; temp_array[7] <= arr_7;
                        temp_array[8] <= arr_8; temp_array[9] <= arr_9; temp_array[10] <= arr_10; temp_array[11] <= arr_11;
                        temp_array[12] <= arr_12; temp_array[13] <= arr_13; temp_array[14] <= arr_14; temp_array[15] <= arr_15;

                        pass_counter <= 4'd0;
                        swap_counter <= 4'd0;
                        next_state <= SORTING;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SORTING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Bubble sort pass
                    if (swap_counter < 4'd5) begin
                        // Compare and swap adjacent third indices
                        if (swap_counter == 4'd0 && temp_array[0] > temp_array[3]) begin
                            temp_array[0] <= temp_array[3];
                            temp_array[3] <= temp_array[0];
                        end
                        if (swap_counter == 4'd1 && temp_array[3] > temp_array[6]) begin
                            temp_array[3] <= temp_array[6];
                            temp_array[6] <= temp_array[3];
                        end
                        if (swap_counter == 4'd2 && temp_array[6] > temp_array[9]) begin
                            temp_array[6] <= temp_array[9];
                            temp_array[9] <= temp_array[6];
                        end
                        if (swap_counter == 4'd3 && temp_array[9] > temp_array[12]) begin
                            temp_array[9] <= temp_array[12];
                            temp_array[12] <= temp_array[9];
                        end
                        if (swap_counter == 4'd4 && temp_array[12] > temp_array[15]) begin
                            temp_array[12] <= temp_array[15];
                            temp_array[15] <= temp_array[12];
                        end

                        swap_counter <= swap_counter + 4'd1;
                    end else begin
                        swap_counter <= 4'd0;
                        pass_counter <= pass_counter + 4'd1;

                        // Check if all passes completed
                        if (pass_counter >= 4'd5 || cycle_count >= MAX_CYCLES) begin
                            next_state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Output results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_0 <= 8'd0; result_1 <= 8'd0; result_2 <= 8'd0; result_3 <= 8'd0;
            result_4 <= 8'd0; result_5 <= 8'd0; result_6 <= 8'd0; result_7 <= 8'd0;
            result_8 <= 8'd0; result_9 <= 8'd0; result_10 <= 8'd0; result_11 <= 8'd0;
            result_12 <= 8'd0; result_13 <= 8'd0; result_14 <= 8'd0; result_15 <= 8'd0;
        end else if (state == DONE_STATE) begin
            // Output sorted array
            result_0 <= temp_array[0]; result_1 <= temp_array[1]; result_2 <= temp_array[2]; result_3 <= temp_array[3];
            result_4 <= temp_array[4]; result_5 <= temp_array[5]; result_6 <= temp_array[6]; result_7 <= temp_array[7];
            result_8 <= temp_array[8]; result_9 <= temp_array[9]; result_10 <= temp_array[10]; result_11 <= temp_array[11];
            result_12 <= temp_array[12]; result_13 <= temp_array[13]; result_14 <= temp_array[14]; result_15 <= temp_array[15];
        end
    end

endmodule