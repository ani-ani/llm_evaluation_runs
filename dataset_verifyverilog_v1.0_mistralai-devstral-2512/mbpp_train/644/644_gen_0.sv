module array_reverser(
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
    input wire [3:0] k,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal array storage
    reg [7:0] internal_arr [0:7];
    reg [3:0] current_k;
    reg [2:0] left_ptr, right_ptr;
    reg processing_done;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            processing_done <= 1'b0;
            left_ptr <= 3'd0;
            right_ptr <= 3'd0;
            current_k <= 4'd0;

            // Initialize internal array
            internal_arr[0] <= 8'd0;
            internal_arr[1] <= 8'd0;
            internal_arr[2] <= 8'd0;
            internal_arr[3] <= 8'd0;
            internal_arr[4] <= 8'd0;
            internal_arr[5] <= 8'd0;
            internal_arr[6] <= 8'd0;
            internal_arr[7] <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    processing_done <= 1'b0;

                    if (start) begin
                        // Load input array
                        internal_arr[0] <= arr_0;
                        internal_arr[1] <= arr_1;
                        internal_arr[2] <= arr_2;
                        internal_arr[3] <= arr_3;
                        internal_arr[4] <= arr_4;
                        internal_arr[5] <= arr_5;
                        internal_arr[6] <= arr_6;
                        internal_arr[7] <= arr_7;

                        // Handle k edge cases
                        if (k == 4'd0) begin
                            current_k <= 4'd0;
                        end else if (k >= 4'd8) begin
                            current_k <= 4'd8;
                        end else begin
                            current_k <= k;
                        end

                        // Initialize pointers
                        left_ptr <= 3'd0;
                        right_ptr <= current_k - 4'd1;

                        next_state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Perform swap if pointers haven't crossed
                    if (left_ptr < right_ptr) begin
                        reg [7:0] temp;
                        temp <= internal_arr[left_ptr];
                        internal_arr[left_ptr] <= internal_arr[right_ptr];
                        internal_arr[right_ptr] <= temp;

                        left_ptr <= left_ptr + 3'd1;
                        right_ptr <= right_ptr - 3'd1;
                    end else begin
                        processing_done <= 1'b1;
                    end

                    // Check if processing is complete
                    if (processing_done || cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Output the result
                    result_0 <= internal_arr[0];
                    result_1 <= internal_arr[1];
                    result_2 <= internal_arr[2];
                    result_3 <= internal_arr[3];
                    result_4 <= internal_arr[4];
                    result_5 <= internal_arr[5];
                    result_6 <= internal_arr[6];
                    result_7 <= internal_arr[7];

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
endmodule