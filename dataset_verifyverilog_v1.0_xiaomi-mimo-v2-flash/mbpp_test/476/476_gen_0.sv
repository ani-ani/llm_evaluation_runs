module find_min_max_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] INIT     = 2'd1;
    localparam [1:0] PROCESS  = 2'd2;
    localparam [1:0] FINISH   = 2'd3;

    // Internal registers and variables
    reg [1:0] state;
    reg [4:0] counter; // 0 to 16 (5 bits needed)
    reg signed [7:0] current_min;
    reg signed [7:0] current_max;
    reg processing_start;

    // Control flags
    reg start_dly;
    
    // Detect rising edge of start signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_dly <= 1'b0;
        end else begin
            start_dly <= start;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 5'd0;
            current_min <= 8'sd0;
            current_max <= 8'sd0;
            result <= 16'sd0;
            done <= 1'b0;
            processing_start <= 1'b0;
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Clear done when waiting
                    done <= 1'b0;
                    counter <= 5'd0;
                    
                    // Wait for start signal (rising edge)
                    if (start && !start_dly) begin
                        state <= INIT;
                        processing_start <= 1'b1;
                    end
                end

                INIT: begin
                    // Initialize min/max with first element arr[0]
                    current_min <= arr[0];
                    current_max <= arr[0];
                    counter <= 5'd1; // Start from index 1
                    processing_start <= 1'b0;
                    state <= PROCESS;
                end

                PROCESS: begin
                    // Compare current element with min/max
                    if (arr[counter] < current_min) begin
                        current_min <= arr[counter];
                    end
                    if (arr[counter] > current_max) begin
                        current_max <= arr[counter];
                    end
                    
                    counter <= counter + 5'd1;
                    
                    // Check if we've processed all 16 elements (0-15)
                    // counter will be 16 after processing arr[15]
                    if (counter == 15) begin // 15 is the last index
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Calculate the sum of min and max
                    result <= {8'sd0, current_min} + {8'sd0, current_max};
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule