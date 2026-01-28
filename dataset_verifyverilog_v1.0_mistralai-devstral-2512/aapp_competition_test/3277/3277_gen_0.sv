module KSSmoothMinChanges(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] arr,
    input wire [7:0] target_sum,
    output reg [7:0] min_changes,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [3:0] index;
    reg [7:0] group_sums [0:3];
    reg [7:0] group_counts [0:3];
    reg [7:0] group_values [0:3];
    reg [7:0] current_value;
    reg [7:0] total_changes;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            total_changes <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize group arrays
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                group_sums[i] <= 8'd0;
                group_counts[i] <= 8'd0;
                group_values[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        total_changes <= 8'd0;
                        
                        // Reset group arrays
                        integer i;
                        for (i = 0; i < 4; i = i + 1) begin
                            group_sums[i] <= 8'd0;
                            group_counts[i] <= 8'd0;
                            group_values[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (index < 4'd16) begin
                        // Extract current value
                        current_value <= arr[(index * 8) +: 8];
                        
                        // Determine group
                        reg [1:0] group = index[1:0];
                        
                        // Accumulate sum and count for the group
                        group_sums[group] <= group_sums[group] + current_value;
                        group_counts[group] <= group_counts[group] + 8'd1;
                        
                        // Update index
                        index <= index + 4'd1;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate target values for each group
                    // We'll use the average value for each group, then adjust to meet target_sum
                    reg [7:0] target_values [0:3];
                    reg [7:0] sum_target = 8'd0;
                    integer i;
                    
                    // Calculate initial target values (average)
                    for (i = 0; i < 4; i = i + 1) begin
                        if (group_counts[i] > 8'd0) begin
                            target_values[i] = group_sums[i] / group_counts[i];
                        end else begin
                            target_values[i] = 8'd0;
                        end
                        sum_target = sum_target + target_values[i];
                    end
                    
                    // Adjust to meet target_sum
                    reg signed [8:0] diff = {1'b0, target_sum} - {1'b0, sum_target};
                    reg [7:0] adjustment = 8'd0;
                    
                    if (diff > 8'd0) begin
                        // Need to increase sum
                        adjustment = diff[7:0];
                        for (i = 0; i < 4; i = i + 1) begin
                            if (adjustment > 8'd0) begin
                                reg [7:0] add = (adjustment > 8'd255 - target_values[i]) ? 8'd255 - target_values[i] : adjustment;
                                target_values[i] = target_values[i] + add;
                                adjustment = adjustment - add;
                            end
                        end
                    end else if (diff < 8'd0) begin
                        // Need to decrease sum
                        adjustment = (-diff)[7:0];
                        for (i = 0; i < 4; i = i + 1) begin
                            if (adjustment > 8'd0) begin
                                reg [7:0] sub = (adjustment > target_values[i]) ? target_values[i] : adjustment;
                                target_values[i] = target_values[i] - sub;
                                adjustment = adjustment - sub;
                            end
                        end
                    end
                    
                    // Store target values
                    for (i = 0; i < 4; i = i + 1) begin
                        group_values[i] <= target_values[i];
                    end
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate total changes
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        reg [1:0] group = i[1:0];
                        reg [7:0] value = arr[(i * 8) +: 8];
                        if (value != group_values[group]) begin
                            total_changes <= total_changes + 8'd1;
                        end
                    end
                    
                    min_changes <= total_changes;
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