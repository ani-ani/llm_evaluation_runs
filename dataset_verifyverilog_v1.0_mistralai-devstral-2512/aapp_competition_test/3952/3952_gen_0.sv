module SubsetCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] x_i,
    input wire [7:0] y_i,
    input wire valid_i,
    input wire done_i,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Point storage (16 points max)
    reg [7:0] x [0:15];
    reg [7:0] y [0:15];
    reg [3:0] point_count;
    
    // Sorted unique x coordinates
    reg [7:0] sorted_x [0:15];
    reg [3:0] unique_x_count;
    
    // Computation variables
    reg [3:0] left_idx, right_idx;
    reg [15:0] temp_count;
    reg [15:0] subset_count;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            point_count <= 4'd0;
            unique_x_count <= 4'd0;
            left_idx <= 4'd0;
            right_idx <= 4'd0;
            temp_count <= 16'd0;
            subset_count <= 16'd0;
            cycle_count <= 8'd0;
            
            // Initialize point storage
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                x[i] <= 8'd0;
                y[i] <= 8'd0;
                sorted_x[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INPUT;
                end
            end
            
            INPUT: begin
                if (done_i) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES || (left_idx == unique_x_count && right_idx == unique_x_count)) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Input collection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            point_count <= 4'd0;
        end else if (state == INPUT && valid_i) begin
            if (point_count < 16) begin
                x[point_count] <= x_i;
                y[point_count] <= y_i;
                point_count <= point_count + 4'd1;
            end
        end
    end

    // Sort and get unique x coordinates (simplified for synthesis)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            unique_x_count <= 4'd0;
        end else if (state == INPUT && done_i) begin
            // Simple bubble sort for unique x values
            integer i, j;
            reg [7:0] temp_sorted [0:15];
            reg [7:0] temp_unique [0:15];
            
            // Copy all x values
            for (i = 0; i < 16; i = i + 1) begin
                temp_sorted[i] = x[i];
            end
            
            // Sort (bubble sort for small n)
            for (i = 0; i < 15; i = i + 1) begin
                for (j = 0; j < 15 - i; j = j + 1) begin
                    if (temp_sorted[j] > temp_sorted[j + 1]) begin
                        reg [7:0] temp = temp_sorted[j];
                        temp_sorted[j] = temp_sorted[j + 1];
                        temp_sorted[j + 1] = temp;
                    end
                end
            end
            
            // Get unique values
            temp_unique[0] = temp_sorted[0];
            unique_x_count = 1;
            for (i = 1; i < 16; i = i + 1) begin
                if (temp_sorted[i] != temp_sorted[i - 1] && temp_sorted[i] != 0) begin
                    temp_unique[unique_x_count] = temp_sorted[i];
                    unique_x_count = unique_x_count + 1;
                end
            end
            
            // Store sorted unique x values
            for (i = 0; i < 16; i = i + 1) begin
                sorted_x[i] = temp_unique[i];
            end
        end
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_idx <= 4'd0;
            right_idx <= 4'd0;
            temp_count <= 16'd0;
            subset_count <= 16'd0;
            cycle_count <= 8'd0;
        end else if (state == COMPUTE) begin
            cycle_count <= cycle_count + 8'd1;
            
            // Enumerate all x-interval pairs
            if (left_idx < unique_x_count) begin
                if (right_idx < unique_x_count && right_idx > left_idx) begin
                    // Count points in current x-interval
                    integer i;
                    reg [15:0] points_in_range = 16'd0;
                    reg [15:0] y_bits = 16'd0;
                    
                    for (i = 0; i < point_count; i = i + 1) begin
                        if (x[i] > sorted_x[left_idx] && x[i] < sorted_x[right_idx]) begin
                            points_in_range = points_in_range + 16'd1;
                            y_bits = y_bits | (1 << i);
                        end
                    end
                    
                    // Count unique y-threshold subsets
                    if (points_in_range > 0) begin
                        integer j, k;
                        reg [15:0] unique_subsets = 16'd0;
                        reg [15:0] current_subset;
                        
                        for (j = 0; j < point_count; j = j + 1) begin
                            if (y_bits[j]) begin
                                current_subset = 16'd0;
                                for (k = 0; k < point_count; k = k + 1) begin
                                    if (y_bits[k] && y[k] > y[j]) begin
                                        current_subset = current_subset | (1 << k);
                                    end
                                end
                                if (current_subset != 0) begin
                                    unique_subsets = unique_subsets + 16'd1;
                                end
                            end
                        end
                        
                        temp_count = temp_count + unique_subsets;
                    end
                    
                    right_idx = right_idx + 4'd1;
                end else begin
                    right_idx = left_idx + 4'd2;
                    left_idx = left_idx + 4'd1;
                end
            end else begin
                subset_count = temp_count;
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end
                INPUT: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end
                COMPUTE: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end
                FINISH: begin
                    result <= subset_count;
                    done <= 1'b1;
                end
                default: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule