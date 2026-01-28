module FrequencyCalculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] lists [0:3] [0:3],
    output reg [7:0] result_val [0:7],
    output reg [7:0] result_cnt [0:7],
    output reg [3:0] result_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FLATTEN = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] flat [0:15];
    reg [4:0] flat_idx;
    reg [4:0] process_idx;
    reg [2:0] i;
    reg [2:0] j;
    reg [7:0] current_val;
    reg [2:0] search_idx;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result_count <= 4'd0;
            flat_idx <= 5'd0;
            process_idx <= 5'd0;
            i <= 3'd0;
            j <= 3'd0;
            search_idx <= 3'd0;
            cycle_count <= 5'd0;
            current_val <= 8'd0;
            
            // Reset result arrays
            for (int k = 0; k < 8; k = k + 1) begin
                result_val[k] <= 8'd0;
                result_cnt[k] <= 8'd0;
            end
            
            // Reset flat array
            for (int k = 0; k < 16; k = k + 1) begin
                flat[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    
                    if (start) begin
                        // Reset outputs for new operation
                        result_count <= 4'd0;
                        for (int k = 0; k < 8; k = k + 1) begin
                            result_val[k] <= 8'd0;
                            result_cnt[k] <= 8'd0;
                        end
                        
                        // Start flattening
                        flat_idx <= 5'd0;
                        i <= 3'd0;
                        j <= 3'd0;
                        state <= FLATTEN;
                    end
                end
                
                FLATTEN: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Flatten 4x4 array to 1D array (16 elements)
                    if (flat_idx < 5'd16) begin
                        flat[flat_idx] <= lists[i][j];
                        flat_idx <= flat_idx + 5'd1;
                        
                        if (j < 3'd3) begin
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        // Finished flattening
                        process_idx <= 5'd0;
                        state <= COUNT;
                    end
                end
                
                COUNT: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    if (process_idx < 5'd16 && cycle_count < MAX_CYCLES) begin
                        current_val <= {4'd0, flat[process_idx]};
                        
                        // Search for existing value in result_val
                        search_idx <= 3'd0;
                        
                        // Check if value exists
                        if (result_count > 4'd0) begin
                            for (int k = 0; k < 8; k = k + 1) begin
                                if (k < result_count && result_val[k] == {4'd0, flat[process_idx]}) begin
                                    // Found existing value - increment count
                                    result_cnt[k] <= result_cnt[k] + 8'd1;
                                    // Set flag to indicate found
                                    state <= OUTPUT;
                                end else if (k == 0 && result_count == 4'd0) begin
                                    // First element, no search needed
                                    result_val[0] <= {4'd0, flat[process_idx]};
                                    result_cnt[0] <= 8'd1;
                                    result_count <= 4'd1;
                                    state <= OUTPUT;
                                end
                            end
                        end else begin
                            // First element ever
                            result_val[0] <= {4'd0, flat[process_idx]};
                            result_cnt[0] <= 8'd1;
                            result_count <= 4'd1;
                            state <= OUTPUT;
                        end
                        
                        process_idx <= process_idx + 5'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                OUTPUT: begin
                    cycle_count <= cycle_count + 5'd1;
                    state <= COUNT;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule