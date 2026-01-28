module CountSumEqualsProduct(
    input clk,
    input rst_n,
    input start,
    input [9:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE  = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] i;          // Outer loop: start index
    reg [3:0] j;          // Inner loop: end index
    reg [3:0] arr_len;    // Captured array length
    reg [9:0] arr_captured [0:15];  // Captured array values
    reg [15:0] sum_acc;   // 16-bit sum accumulator
    reg [31:0] prod_acc;  // 32-bit product accumulator
    reg [7:0] count;      // Result counter
    reg [3:0] calc_idx;   // Index for iterating through subarray
    reg calc_done;        // Flag for subarray calculation complete

    // Counter for timeout protection
    reg [11:0] cycle_count;  // 12 bits for up to 4095 cycles (exceeds 2000)
    localparam [11:0] MAX_CYCLES = 12'd2000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            arr_len <= 4'd0;
            sum_acc <= 16'd0;
            prod_acc <= 32'd0;
            count <= 8'd0;
            calc_idx <= 4'd0;
            calc_done <= 1'b0;
            cycle_count <= 12'd0;
            // Initialize captured array to avoid X values
            integer idx;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                arr_captured[idx] <= 10'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 12'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    calc_idx <= 4'd0;
                    calc_done <= 1'b0;
                    
                    if (start) begin
                        // Capture inputs
                        arr_len <= len;
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < len) begin
                                arr_captured[k] <= arr[k];
                            end else begin
                                arr_captured[k] <= 10'd0;
                            end
                        end
                        
                        // Reset result
                        count <= 8'd0;
                        state <= CALCULATING;
                    end
                end
                
                CALCULATING: begin
                    cycle_count <= cycle_count + 12'd1;
                    
                    // Check timeout (should not happen within 2000 cycles)
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        // Check if outer loop is valid (i <= len-2)
                        if (i < arr_len - 4'd2) begin
                            // Check if inner loop is valid (j <= len-1)
                            if (j < arr_len - 4'd1) begin
                                // Check if we need to start new subarray calculation
                                if (!calc_done) begin
                                    // Initialize accumulators for current subarray [i:j]
                                    if (calc_idx == i) begin
                                        sum_acc <= {6'd0, arr_captured[i]};
                                        prod_acc <= {22'd0, arr_captured[i]};
                                        calc_idx <= i + 4'd1;
                                    end else if (calc_idx <= j) begin
                                        // Accumulate sum (safe: max 16*1024=16384)
                                        sum_acc <= sum_acc + {6'd0, arr_captured[calc_idx]};
                                        
                                        // Accumulate product with overflow protection
                                        // If product exceeds safe threshold, cap it
                                        if (prod_acc < 32'hFFFF0000) begin
                                            prod_acc <= prod_acc * {22'd0, arr_captured[calc_idx]};
                                        end
                                        
                                        calc_idx <= calc_idx + 4'd1;
                                    end else begin
                                        // Calculation done for this subarray
                                        calc_done <= 1'b1;
                                    end
                                end else begin
                                    // Check if sum == product
                                    if (sum_acc == prod_acc) begin
                                        count <= count + 8'd1;
                                    end
                                    
                                    // Move to next subarray
                                    j <= j + 4'd1;
                                    calc_idx <= i;  // Reset for next subarray
                                    calc_done <= 1'b0;
                                end
                            end else begin
                                // Inner loop done, move to next start index
                                i <= i + 4'd1;
                                j <= i + 4'd1;  // Reset j to i+1
                                calc_idx <= i + 4'd1;  // Prepare for next i
                                calc_done <= 1'b0;
                            end
                        end else begin
                            // Outer loop done, all subarrays processed
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule