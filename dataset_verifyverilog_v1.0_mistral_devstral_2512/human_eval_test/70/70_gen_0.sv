module strange_sort(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SORT    = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] sorted_arr [0:7];
    reg [3:0] output_index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize internal array
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            output_index <= 4'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                sorted_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Copy input array to internal buffer
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < len)
                                sorted_arr[i] <= arr[i];
                            else
                                sorted_arr[i] <= 8'd0;
                        end
                        state <= SORT;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Bubble sort implementation
                    reg [7:0] temp;
                    reg swap;
                    integer j;
                    for (i = 0; i < 7; i = i + 1) begin
                        for (j = 0; j < 7 - i; j = j + 1) begin
                            if (sorted_arr[j] > sorted_arr[j + 1]) begin
                                temp <= sorted_arr[j];
                                sorted_arr[j] <= sorted_arr[j + 1];
                                sorted_arr[j + 1] <= temp;
                            end
                        end
                    end
                    // Exit condition
                    if (cycle_count >= MAX_CYCLES || cycle_count > 8'd1) begin
                        state <= OUTPUT;
                        output_index <= 4'd0;
                    end
                end

                OUTPUT: begin
                    // Generate done pulse for one cycle
                    if (output_index < len) begin
                        // Alternate between smallest and largest
                        if (output_index[0] == 1'b0) begin
                            // Even index: smallest remaining
                            result <= sorted_arr[output_index / 2];
                        end else begin
                            // Odd index: largest remaining
                            result <= sorted_arr[len - 1 - (output_index - 1) / 2];
                        end
                        done <= 1'b1;
                        output_index <= output_index + 4'd1;
                    end else begin
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule