module kth_element(
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SORTING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [2:0] pass_count;      // 0 to 6
    reg [2:0] compare_count;   // 0 to 6-pass
    reg [7:0] arr_reg [0:7];   // Array storage
    reg [7:0] swap_temp;
    reg [2:0] k_reg;           // Store k value

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'b0;
            done <= 1'b0;
            pass_count <= 3'b0;
            compare_count <= 3'b0;
            k_reg <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize array from inputs
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        // Store k value
                        k_reg <= k;
                        // Initialize counters
                        pass_count <= 3'b0;
                        compare_count <= 3'b0;
                        state <= SORTING;
                    end
                end

                SORTING: begin
                    // Compare and swap logic
                    if (arr_reg[compare_count] > arr_reg[compare_count + 1]) begin
                        // Swap
                        arr_reg[compare_count] <= arr_reg[compare_count + 1];
                        arr_reg[compare_count + 1] <= arr_reg[compare_count];
                    end

                    // Increment inner loop counter
                    if (compare_count < 3'd6 - pass_count) begin
                        compare_count <= compare_count + 1'b1;
                    end else begin
                        // End of current pass
                        compare_count <= 3'b0;
                        
                        // Increment outer loop counter
                        if (pass_count < 3'd6) begin
                            pass_count <= pass_count + 1'b1;
                        end else begin
                            // Sorting complete, get result
                            // k_reg is 1-8, need to convert to 0-7 index
                            case (k_reg)
                                3'd1: result <= arr_reg[0];
                                3'd2: result <= arr_reg[1];
                                3'd3: result <= arr_reg[2];
                                3'd4: result <= arr_reg[3];
                                3'd5: result <= arr_reg[4];
                                3'd6: result <= arr_reg[5];
                                3'd7: result <= arr_reg[6];
                                3'd0: result <= arr_reg[7]; // k=8 encoded as 0 in 3-bit
                                default: result <= arr_reg[0];
                            endcase
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    // Wait for start to go low before accepting new start
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule