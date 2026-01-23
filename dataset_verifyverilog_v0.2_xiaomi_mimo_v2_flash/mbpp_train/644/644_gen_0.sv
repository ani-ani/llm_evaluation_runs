module reverse_array_upto_k (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [7:0] arr_in [0:7],
    output reg [7:0] arr_out [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state;
    reg [2:0] left;
    reg [2:0] right;
    reg [2:0] swap_count;
    
    // Next state logic and state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            left <= 3'd0;
            right <= 3'd0;
            swap_count <= 3'd0;
            // Reset output array
            arr_out[0] <= 8'b0;
            arr_out[1] <= 8'b0;
            arr_out[2] <= 8'b0;
            arr_out[3] <= 8'b0;
            arr_out[4] <= 8'b0;
            arr_out[5] <= 8'b0;
            arr_out[6] <= 8'b0;
            arr_out[7] <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Copy input array to output array
                        arr_out[0] <= arr_in[0];
                        arr_out[1] <= arr_in[1];
                        arr_out[2] <= arr_in[2];
                        arr_out[3] <= arr_in[3];
                        arr_out[4] <= arr_in[4];
                        arr_out[5] <= arr_in[5];
                        arr_out[6] <= arr_in[6];
                        arr_out[7] <= arr_in[7];
                        
                        // Initialize pointers
                        left <= 3'd0;
                        right <= k - 3'd1;
                        swap_count <= 3'd0;
                        
                        // Check if k is valid (1-8) and needs processing
                        if (k >= 3'd1 && k <= 3'd7) begin
                            state <= PROCESSING;
                        end else if (k == 3'd0) begin
                            // No reversal needed, go directly to DONE
                            state <= DONE;
                        end else begin
                            // k = 8 (or more, but treated as 8 in 3-bit), process all
                            state <= PROCESSING;
                        end
                    end
                end
                
                PROCESSING: begin
                    // Swap current elements
                    if (left < right) begin
                        arr_out[left] <= arr_out[right];
                        arr_out[right] <= arr_out[left];
                        
                        // Update pointers
                        left <= left + 3'd1;
                        right <= right - 3'd1;
                        swap_count <= swap_count + 3'd1;
                    end else begin
                        // Swap complete or no swap needed
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Wait for reset or start signal to restart
                    if (start) begin
                        // Restart process
                        done <= 1'b0;
                        arr_out[0] <= arr_in[0];
                        arr_out[1] <= arr_in[1];
                        arr_out[2] <= arr_in[2];
                        arr_out[3] <= arr_in[3];
                        arr_out[4] <= arr_in[4];
                        arr_out[5] <= arr_in[5];
                        arr_out[6] <= arr_in[6];
                        arr_out[7] <= arr_in[7];
                        left <= 3'd0;
                        right <= k - 3'd1;
                        swap_count <= 3'd0;
                        if (k >= 3'd1 && k <= 3'd7) begin
                            state <= PROCESSING;
                        end else if (k == 3'd0) begin
                            state <= DONE;
                        end else begin
                            state <= PROCESSING;
                        end
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
