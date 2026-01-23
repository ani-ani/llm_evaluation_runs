module mean_absolute_deviation (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] num_elements,
    input [31:0] data_in,
    input data_valid,
    output reg [31:0] result,
    output reg done,
    output reg [2:0] read_index
);

// Internal registers
reg [31:0] data_buf [7:0];
reg [2:0] data_count = 0;
reg [2:0] captured_num = 0;
reg [31:0] sum_data = 0;
reg [31:0] mean_value = 0;
reg [31:0] deviation_sum = 0;
reg [2:0] dev_index = 0;
reg [2:0] state = 0; // 0:IDLE, 1:READ_MEAN, 2:READ_DATA, 3:COMPUTE, 4:DIVIDE, 5:DONE

// read_index is assigned to data_count
assign read_index = data_count;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        data_count <= 0;
        captured_num <= 0;
        sum_data <= 0;
        mean_value <= 0;
        deviation_sum <= 0;
        dev_index <= 0;
        state <= 0;
    end else begin
        case (state)
            0: // IDLE
                if (start) begin
                    captured_num <= num_elements;
                    data_count <= 0;
                    dev_index <= 0;
                    sum_data <= 0;
                    state <= 1; // move to READ_MEAN
                end
            end
            1: // READ_MEAN: collect data
                if (data_valid) begin
                    if (data_count < captured_num) begin
                        data_buf[data_count] <= data_in;
                        sum_data <= sum_data + data_in;
                        data_count <= data_count + 1;
                    end else begin
                        // Compute mean
                        case(captured_num)
                            1: mean_value = sum_data;
                            2: mean_value = sum_data >> 1;
                            4: mean_value = sum_data >> 2;
                            8: mean_value = sum_data >> 3;
                            default: mean_value = sum_data; // no shift for non-powers of two
                        endcase
                        state <= 2; // move to READ_DATA
                    end
                end
            end
            2: // READ_DATA: compute absolute deviations and sum
                if (dev_index < captured_num) begin
                    // Compute difference inline
                    if (data_buf[dev_index] - mean_value < 0) begin
                        deviation_sum <= deviation_sum + (~ (data_buf[dev_index] - mean_value) + 1);
                    end else begin
                        deviation_sum <= deviation_sum + (data_buf[dev_index] - mean_value);
                    end
                    dev_index <= dev_index + 1;
                end else begin
                    // All elements processed, move to COMPUTE
                    state <= 3;
                end
            end
            3: // COMPUTE: just transition
                state <= 4;
            end
            4: // DIVIDE: compute final result
                case(captured_num)
                    1: result = deviation_sum;
                    2: result = deviation_sum >> 1;
                    4: result = deviation_sum >> 2;
                    8: result = deviation_sum >> 3;
                    default: result = deviation_sum;
                endcase
                done <= 1;
                state <= 5;
            end
            5: // DONE: stay here
                // no action
            endcase
        endcase
    end
endmodule