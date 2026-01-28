module sort_even_indices (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    output reg signed [7:0] result [0:15],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] BUBBLE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // State register
    reg [2:0] state, next_state;

    // Sorting registers for even indices (8 elements)
    reg signed [7:0] even_reg [0:7];
    reg signed [7:0] temp_even [0:7];
    
    // Counter registers
    reg [3:0] i_counter;  // Outer loop counter (0-7)
    reg [3:0] j_counter;  // Inner loop counter (0-6)
    reg [3:0] cycle_count; // Safety counter
    
    // Control flags
    reg swap_flag;
    reg [2:0] pass_count;
    
    // Loop variables
    integer idx;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            for (idx = 0; idx < 16; idx = idx + 1) begin
                result[idx] <= 8'sd0;
            end
            for (idx = 0; idx < 8; idx = idx + 1) begin
                even_reg[idx] <= 8'sd0;
                temp_even[idx] <= 8'sd0;
            end
            done <= 1'b0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            cycle_count <= 4'd0;
            swap_flag <= 1'b0;
            pass_count <= 3'd0;
            next_state <= IDLE;
        end else begin
            // Default values
            done <= 1'b0;
            next_state <= state;

            case (state)
                IDLE: begin
                    // Clear done signal
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    pass_count <= 3'd0;
                    i_counter <= 4'd0;
                    j_counter <= 4'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load even indices from input array
                    even_reg[0] <= arr[0];
                    even_reg[1] <= arr[2];
                    even_reg[2] <= arr[4];
                    even_reg[3] <= arr[6];
                    even_reg[4] <= arr[8];
                    even_reg[5] <= arr[10];
                    even_reg[6] <= arr[12];
                    even_reg[7] <= arr[14];
                    
                    // Pass through odd indices
                    result[1] <= arr[1];
                    result[3] <= arr[3];
                    result[5] <= arr[5];
                    result[7] <= arr[7];
                    result[9] <= arr[9];
                    result[11] <= arr[11];
                    result[13] <= arr[13];
                    result[15] <= arr[15];
                    
                    i_counter <= 4'd0;
                    j_counter <= 4'd0;
                    cycle_count <= 4'd0;
                    swap_flag <= 1'b0;
                    
                    next_state <= BUBBLE;
                end

                BUBBLE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Bubble sort for 8 even elements
                    // Standard bubble sort algorithm
                    if (i_counter < 8'd7) begin
                        if (j_counter < (8'd7 - i_counter)) begin
                            // Compare and swap
                            if (even_reg[j_counter] > even_reg[j_counter + 1]) begin
                                // Swap
                                temp_even[j_counter] <= even_reg[j_counter + 1];
                                temp_even[j_counter + 1] <= even_reg[j_counter];
                                swap_flag <= 1'b1;
                            end else begin
                                swap_flag <= 1'b0;
                            end
                            j_counter <= j_counter + 4'd1;
                        end else begin
                            // Update even_reg with swapped values
                            if (swap_flag) begin
                                for (idx = 0; idx < 8; idx = idx + 1) begin
                                    even_reg[idx] <= temp_even[idx];
                                end
                            end
                            i_counter <= i_counter + 4'd1;
                            j_counter <= 4'd0;
                        end
                    end else begin
                        // Sorting complete or safety timeout
                        if (cycle_count >= 4'd15 || i_counter >= 4'd7) begin
                            // Place sorted even values into result
                            result[0] <= even_reg[0];
                            result[2] <= even_reg[1];
                            result[4] <= even_reg[2];
                            result[6] <= even_reg[3];
                            result[8] <= even_reg[4];
                            result[10] <= even_reg[5];
                            result[12] <= even_reg[6];
                            result[14] <= even_reg[7];
                            
                            next_state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule