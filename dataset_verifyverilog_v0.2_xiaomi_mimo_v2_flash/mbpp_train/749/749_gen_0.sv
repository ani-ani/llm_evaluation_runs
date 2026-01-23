module sort_numeric_strings(
    input clk,
    input rst_n,
    input start,
    input [7:0] nums [0:15],
    output reg [7:0] sorted_nums [0:15],
    output reg done
);

    parameter N = 16;
    
    // Internal buffer
    reg [7:0] buffer [0:15];
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam PROCESSING = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] state;
    reg [3:0] i; // Outer loop counter (0 to N-2)
    reg [3:0] j; // Inner loop counter (0 to N-2-i)
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            // Reset output array (optional but good practice)
            for (k = 0; k < 16; k = k + 1) begin
                sorted_nums[k] <= 8'sd0;
                buffer[k] <= 8'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                LOAD: begin
                    // Capture input array
                    for (k = 0; k < 16; k = k + 1) begin
                        buffer[k] <= nums[k];
                    end
                    state <= PROCESSING;
                end
                
                PROCESSING: begin
                    // Compare and swap logic
                    // buffer[j] and buffer[j+1] are signed 8-bit
                    if (buffer[j] > buffer[j+1]) begin
                        buffer[j] <= buffer[j+1];
                        buffer[j+1] <= buffer[j];
                    end
                    
                    // Update counters
                    if (j < (N - 2 - i)) begin
                        j <= j + 1;
                    end else begin
                        // Inner loop finished, reset j and increment i
                        j <= 0;
                        if (i < N - 2) begin
                            i <= i + 1;
                        end else begin
                            // Outer loop finished (i reached N-2)
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    // Copy buffer to output
                    for (k = 0; k < 16; k = k + 1) begin
                        sorted_nums[k] <= buffer[k];
                    end
                    done <= 1'b1;
                    
                    // Wait for reset or start to go high again
                    // Note: If start goes high while in DONE, we transition to LOAD on next cycle
                    if (start) begin
                        state <= LOAD;
                        done <= 1'b0;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule