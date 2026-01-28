module MaxFrequencyFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SCAN    = 3'd1;
    localparam [2:0] COUNT   = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] current_value;
    reg [7:0] max_value;
    reg [7:0] max_count;
    reg [7:0] temp_count;
    reg [3:0] index;
    reg [3:0] outer_index;
    reg [3:0] inner_index;
    reg [7:0] unique_values [0:15];
    reg [7:0] counts [0:15];
    reg [3:0] unique_count;
    reg [7:0] current_unique;
    reg found;
    reg [7:0] temp_max_value;
    reg [7:0] temp_max_count;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            current_value <= 8'd0;
            max_value <= 8'd0;
            max_count <= 8'd0;
            temp_count <= 8'd0;
            index <= 4'd0;
            outer_index <= 4'd0;
            inner_index <= 4'd0;
            unique_count <= 4'd0;
            current_unique <= 8'd0;
            found <= 1'b0;
            temp_max_value <= 8'd0;
            temp_max_count <= 8'd0;
            cycle_count <= 8'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                unique_values[i] <= 8'd0;
                counts[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SCAN;
                        index <= 4'd0;
                        unique_count <= 4'd0;
                        current_value <= arr[0];
                        
                        // Initialize arrays
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            unique_values[i] <= 8'd0;
                            counts[i] <= 8'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current value is already in unique_values
                    found <= 1'b0;
                    integer j;
                    for (j = 0; j < unique_count; j = j + 1) begin
                        if (unique_values[j] == current_value) begin
                            found <= 1'b1;
                        end
                    end
                    
                    // If not found, add to unique_values
                    if (!found && unique_count < len) begin
                        unique_values[unique_count] <= current_value;
                        unique_count <= unique_count + 4'd1;
                    end
                    
                    // Move to next element
                    index <= index + 4'd1;
                    if (index < len) begin
                        current_value <= arr[index];
                        next_state <= SCAN;
                    end else begin
                        next_state <= COUNT;
                        outer_index <= 4'd0;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Count occurrences of current unique value
                    temp_count <= 8'd0;
                    integer k;
                    for (k = 0; k < len; k = k + 1) begin
                        if (arr[k] == unique_values[outer_index]) begin
                            temp_count <= temp_count + 8'd1;
                        end
                    end
                    
                    counts[outer_index] <= temp_count;
                    
                    // Move to next unique value
                    outer_index <= outer_index + 4'd1;
                    if (outer_index < unique_count) begin
                        next_state <= COUNT;
                    end else begin
                        next_state <= COMPARE;
                        inner_index <= 4'd0;
                        temp_max_value <= unique_values[0];
                        temp_max_count <= counts[0];
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Find the value with maximum count
                    if (counts[inner_index] > temp_max_count || 
                        (counts[inner_index] == temp_max_count && 
                         unique_values[inner_index] < temp_max_value)) begin
                        temp_max_value <= unique_values[inner_index];
                        temp_max_count <= counts[inner_index];
                    end
                    
                    // Move to next unique value
                    inner_index <= inner_index + 4'd1;
                    if (inner_index < unique_count) begin
                        next_state <= COMPARE;
                    end else begin
                        next_state <= DONE_STATE;
                        max_value <= temp_max_value;
                        max_count <= temp_max_count;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= max_value;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 8'd0;
                end
            endcase
        end
    end

endmodule