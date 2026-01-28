module bitonic_subsequence_max (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] COMPUTE_MSIBS  = 3'd1;
    localparam [2:0] COMPUTE_MSDBS  = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] DONE_STATE     = 3'd4;

    // Registers
    reg [2:0] state;
    reg [3:0] i, j;  // Loop counters
    reg signed [15:0] msibs [0:15];  // MSIBS memory
    reg signed [15:0] msdbs [0:15];  // MSDBS memory
    reg signed [15:0] temp_sum;
    reg signed [15:0] max_result;
    reg signed [7:0] arr_reg [0:15];  // Store input array
    reg [3:0] len_reg;

    // State transition and computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            temp_sum <= 16'sd0;
            max_result <= 16'sd0;
            len_reg <= 4'd0;
            // Initialize memory arrays
            begin : reset_arrays
                integer k;
                for (k = 0; k < 16; k = k + 1) begin
                    msibs[k] <= 16'sd0;
                    msdbs[k] <= 16'sd0;
                    arr_reg[k] <= 8'sd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    max_result <= 16'sd0;
                    if (start) begin
                        // Store input array and length
                        len_reg <= len;
                        begin : store_input
                            integer idx;
                            for (idx = 0; idx < 16; idx = idx + 1) begin
                                if (idx < len)
                                    arr_reg[idx] <= arr[idx];
                                else
                                    arr_reg[idx] <= 8'sd0;
                            end
                        end
                        state <= COMPUTE_MSIBS;
                    end
                end

                COMPUTE_MSIBS: begin
                    // MSIBS[i] = arr[i] + max(MSIBS[j] for j < i where arr[j] < arr[i])
                    if (i < len_reg) begin
                        if (j == i) begin
                            // First element or no previous element found
                            msibs[i] <= {8'd0, arr_reg[i]};  // Sign extend to 16 bits
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end else begin
                            // Check if arr[j] < arr[i]
                            if ($signed(arr_reg[j]) < $signed(arr_reg[i])) begin
                                if (j == 4'd0) begin
                                    temp_sum <= {8'd0, arr_reg[i]};  // Initialize with arr[i]
                                end else begin
                                    temp_sum <= msibs[j] + {8'd0, arr_reg[i]};
                                end
                            end
                            // Update MSIBS[i] if needed
                            if ($signed(arr_reg[j]) < $signed(arr_reg[i]) && 
                                $signed(temp_sum) > $signed(msibs[i])) begin
                                msibs[i] <= temp_sum;
                            end
                            j <= j + 4'd1;
                        end
                    end else begin
                        // Done computing MSIBS
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= COMPUTE_MSDBS;
                    end
                end

                COMPUTE_MSDBS: begin
                    // MSDBS[i] = arr[i] + max(MSDBS[j] for j > i where arr[j] < arr[i])
                    if (i < len_reg) begin
                        if (j == len_reg) begin
                            // Finished inner loop
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end else if (j > i) begin
                            // Check if arr[j] < arr[i]
                            if ($signed(arr_reg[j]) < $signed(arr_reg[i])) begin
                                if (j == i + 4'd1) begin
                                    temp_sum <= {8'd0, arr_reg[i]};  // Initialize with arr[i]
                                end else begin
                                    temp_sum <= msdbs[j] + {8'd0, arr_reg[i]};
                                end
                            end
                            // Update MSDBS[i] if needed
                            if ($signed(arr_reg[j]) < $signed(arr_reg[i]) && 
                                $signed(temp_sum) > $signed(msdbs[i])) begin
                                msdbs[i] <= temp_sum;
                            end
                            j <= j + 4'd1;
                        end else begin
                            // Skip j <= i
                            msibs[i] <= {8'd0, arr_reg[i]};  // Initialize MSIBS[i]
                            msdbs[i] <= {8'd0, arr_reg[i]};  // Initialize MSDBS[i]
                            j <= j + 4'd1;
                        end
                    end else begin
                        // Done computing MSDBS
                        i <= 4'd0;
                        state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    // Find max over (MSIBS[i] + MSDBS[i] - arr[i])
                    if (i < len_reg) begin
                        temp_sum <= msibs[i] + msdbs[i] - {8'd0, arr_reg[i]};
                        // Update max_result if needed
                        if ($signed(temp_sum) > $signed(max_result) || i == 4'd0) begin
                            max_result <= temp_sum;
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Done computing result
                        result <= max_result;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
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