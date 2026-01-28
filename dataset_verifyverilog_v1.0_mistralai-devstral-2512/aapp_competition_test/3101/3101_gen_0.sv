module DigitChangeUnsort(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] n,
    output reg [7:0] result_arr [0:7],
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Position and digit change tracking
    reg [2:0] pos;
    reg [3:0] digit_change;
    reg [7:0] new_val;
    reg [7:0] candidate_arr [0:7];

    // Comparison tracking
    reg [2:0] comp_pos;
    reg unsorted_found;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            pos <= 3'd0;
            digit_change <= 4'd0;
            new_val <= 8'd0;
            comp_pos <= 3'd0;
            unsorted_found <= 1'b0;
            valid <= 1'b0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                result_arr[i] <= 8'd0;
                candidate_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        // Initialize result_arr to input
                        for (i = 0; i < 8; i = i + 1) begin
                            result_arr[i] <= arr[i];
                        end
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all positions
                    if (pos >= n - 1) begin
                        state <= FINISH;
                    end else begin
                        // Get current number
                        reg [7:0] current_num = arr[pos];
                        
                        // Extract tens and units digits
                        reg [3:0] tens = current_num[7:4];
                        reg [3:0] units = current_num[3:0];
                        
                        // Try next digit change (0-9)
                        if (digit_change < 4'd10) begin
                            // Compute new value with changed units digit
                            new_val = {tens, digit_change};
                            
                            // Create candidate array
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i == pos) begin
                                    candidate_arr[i] <= new_val;
                                end else begin
                                    candidate_arr[i] <= arr[i];
                                end
                            end
                            
                            // Reset comparison tracking
                            comp_pos <= 3'd0;
                            unsorted_found <= 1'b0;
                            state <= CHECK;
                            digit_change <= digit_change + 4'd1;
                        end else begin
                            // Move to next position
                            pos <= pos + 3'd1;
                            digit_change <= 4'd0;
                        end
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if array is unsorted
                    if (comp_pos < n - 2) begin
                        if (candidate_arr[comp_pos] > candidate_arr[comp_pos + 1]) begin
                            unsorted_found <= 1'b1;
                        end
                        comp_pos <= comp_pos + 3'd1;
                    end else begin
                        if (unsorted_found) begin
                            // Found valid modification
                            valid <= 1'b1;
                            for (i = 0; i < 8; i = i + 1) begin
                                result_arr[i] <= candidate_arr[i];
                            end
                            state <= FINISH;
                        end else begin
                            // Continue processing
                            state <= PROCESS;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule