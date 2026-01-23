module paint_the_numbers (
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input [7:0] data_in,
    input [7:0] num_inputs,
    output reg [7:0] num_colors,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam COLLECT = 3'b001;
    localparam SORT = 3'b010;
    localparam PROCESS = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [7:0] arr [0:99];       // Buffer for 100 elements
    reg [99:0] marked;          // 100-bit shift register for marked status
    reg [7:0] count_in;         // Counter for input collection
    reg [7:0] outer_idx;        // Outer index for sort
    reg [7:0] inner_idx;        // Inner index for sort
    reg [7:0] process_idx;      // Index for processing
    reg [7:0] scan_idx;         // Index for scanning divisible elements
    reg sorting_pass_done;      // Flag to track sorting pass completion
    reg process_scan_done;      // Flag to track scan for current element

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            num_colors <= 8'b0;
            done <= 1'b0;
            count_in <= 8'b0;
            outer_idx <= 8'b0;
            inner_idx <= 8'b0;
            process_idx <= 8'b0;
            scan_idx <= 8'b0;
            marked <= 100'b0;
            sorting_pass_done <= 1'b0;
            process_scan_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT;
                        count_in <= 8'b0;
                    end
                end

                COLLECT: begin
                    if (valid_in) begin
                        arr[count_in] <= data_in;
                        count_in <= count_in + 1'b1;
                    end
                    if (count_in == num_inputs && valid_in) begin
                        state <= SORT;
                        outer_idx <= 8'd0;
                        inner_idx <= 8'd0;
                        sorting_pass_done <= 1'b0;
                    end
                end

                SORT: begin
                    // Bubble sort implementation
                    if (outer_idx < num_inputs - 1) begin
                        if (inner_idx < num_inputs - 1 - outer_idx) begin
                            if (arr[inner_idx] > arr[inner_idx + 1]) begin
                                // Swap
                                arr[inner_idx] <= arr[inner_idx + 1];
                                arr[inner_idx + 1] <= arr[inner_idx];
                            end
                            inner_idx <= inner_idx + 1'b1;
                        end else begin
                            inner_idx <= 8'd0;
                            outer_idx <= outer_idx + 1'b1;
                        end
                    end else begin
                        state <= PROCESS;
                        process_idx <= 8'd0;
                        num_colors <= 8'b0;
                        marked <= 100'b0;
                    end
                end

                PROCESS: begin
                    // Find next unpainted element
                    if (!process_scan_done) begin
                        if (process_idx < num_inputs) begin
                            if (!marked[process_idx]) begin
                                // Found unpainted element, it becomes a new color
                                num_colors <= num_colors + 1'b1;
                                // Mark this element and all divisible ones
                                scan_idx <= process_idx;
                                process_scan_done <= 1'b1;
                                // Mark the current element immediately
                                marked[process_idx] <= 1'b1;
                            end else begin
                                process_idx <= process_idx + 1'b1;
                            end
                        end else begin
                            state <= DONE;
                            done <= 1'b1;
                        end
                    end else begin
                        // Scanning for divisible elements
                        if (scan_idx < num_inputs) begin
                            // Check divisibility: (arr[scan_idx] % arr[process_idx] == 0)
                            // Since arr[process_idx] is the divisor (minimal element of group)
                            // We check if arr[scan_idx] is divisible by arr[process_idx]
                            // Using repeated subtraction for hardware efficiency
                            if (scan_idx != process_idx) begin
                                reg [7:0] temp;
                                temp = arr[scan_idx];
                                if (arr[process_idx] != 0) begin
                                    while (temp >= arr[process_idx]) begin
                                        temp = temp - arr[process_idx];
                                    end
                                end
                                if (temp == 0 && arr[process_idx] != 0) begin
                                    marked[scan_idx] <= 1'b1;
                                end
                            end
                            scan_idx <= scan_idx + 1'b1;
                        end else begin
                            process_scan_done <= 1'b0;
                            process_idx <= process_idx + 1'b1;
                        end
                    end
                end

                DONE: begin
                    // Stay in DONE until next start
                    if (start) begin
                        state <= COLLECT;
                        count_in <= 8'b0;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
