module find_closest_elements #(
    parameter N = 8
) (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in_valid,
    input [N-1:0][31:0] numbers,
    output reg [31:0] smaller,
    output reg [31:0] larger,
    output reg done,
    output reg valid
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam SORTING = 3'b010;
    localparam COMPARING = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [N-1:0][31:0] sorted_array;
    reg [N-1:0][31:0] next_sorted_array;
    reg [31:0] min_diff;
    reg [31:0] next_min_diff;
    reg [31:0] best_smaller;
    reg [31:0] next_best_smaller;
    reg [31:0] best_larger;
    reg [31:0] next_best_larger;
    
    // Sorting control registers
    reg [3:0] i; // outer loop index
    reg [3:0] j; // inner loop index
    reg [3:0] next_i;
    reg [3:0] next_j;
    
    // Comparison control registers
    reg [3:0] k;
    reg [3:0] next_k;
    
    // Wires for sorting comparison
    wire [31:0] current_val = sorted_array[j];
    wire [31:0] next_val = sorted_array[j + 1];
    wire compare_result = (current_val > next_val); // greater than
    
    // Wires for comparison phase
    wire [31:0] val1 = sorted_array[k];
    wire [31:0] val2 = sorted_array[k + 1];
    wire [31:0] diff = (val2 - val1); // Since sorted, val2 >= val1
    
    // Data input loading control
    reg load_data;
    reg [2:0] load_count;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sorted_array <= 0;
            min_diff <= 32'hFFFFFFFF; // Max value
            best_smaller <= 0;
            best_larger <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            smaller <= 0;
            larger <= 0;
            done <= 0;
            valid <= 0;
            load_count <= 0;
        end else begin
            state <= next_state;
            sorted_array <= next_sorted_array;
            min_diff <= next_min_diff;
            best_smaller <= next_best_smaller;
            best_larger <= next_best_larger;
            i <= next_i;
            j <= next_j;
            k <= next_k;
            
            // Output registers update in DONE state
            if (state == DONE) begin
                smaller <= best_smaller;
                larger <= best_larger;
                done <= 1'b1;
                valid <= 1'b1;
            end else begin
                done <= 1'b0;
                valid <= 1'b0;
            end
            
            // Handle data loading count
            if (state == IDLE && start) begin
                load_count <= 0;
            end else if (state == INIT && load_data) begin
                load_count <= load_count + 1;
            end
        end
    end
    
    // Combinational next-state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_sorted_array = sorted_array;
        next_min_diff = min_diff;
        next_best_smaller = best_smaller;
        next_best_larger = best_larger;
        next_i = i;
        next_j = j;
        next_k = k;
        load_data = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    next_sorted_array = sorted_array; // Keep current
                    next_i = 0;
                    next_j = 0;
                    next_k = 0;
                    next_min_diff = 32'hFFFFFFFF;
                    next_best_smaller = 0;
                    next_best_larger = 0;
                end
            end
            
            INIT: begin
                // Load data from input when data_in_valid is high
                // For simplicity, we assume data is loaded when valid signals are high
                // In a real scenario, we might wait for specific valid pattern
                // Here we iterate through positions
                if (load_count < N) begin
                    // Load one element per cycle if valid bit is set
                    if (data_in_valid[load_count]) begin
                        next_sorted_array[load_count] = numbers[load_count];
                        load_data = 1'b1;
                    end
                    next_state = INIT;
                end else begin
                    // Transition to sorting
                    next_state = SORTING;
                    next_i = 0;
                    next_j = 0;
                end
            end
            
            SORTING: begin
                // Bubble sort: outer loop i from 0 to N-2
                // Inner loop j from 0 to N-i-2
                if (i < N - 1) begin
                    if (j < N - i - 1) begin
                        // Compare and swap if needed
                        if (sorted_array[j] > sorted_array[j + 1]) begin
                            next_sorted_array[j] = sorted_array[j + 1];
                            next_sorted_array[j + 1] = sorted_array[j];
                        end
                        next_j = j + 1;
                        next_state = SORTING;
                    end else begin
                        // Inner loop done, increment outer loop
                        next_j = 0;
                        next_i = i + 1;
                        next_state = SORTING;
                    end
                end else begin
                    // Sorting complete
                    next_state = COMPARING;
                    next_k = 0;
                    next_min_diff = 32'hFFFFFFFF;
                    next_best_smaller = 0;
                    next_best_larger = 0;
                end
            end
            
            COMPARING: begin
                if (k < N - 1) begin
                    // Compute difference (val2 - val1, already positive)
                    // Since array is sorted, val2 >= val1, diff is positive
                    if (diff < min_diff) begin
                        next_min_diff = diff;
                        next_best_smaller = val1;
                        next_best_larger = val2;
                    end else begin
                        next_min_diff = min_diff;
                        next_best_smaller = best_smaller;
                        next_best_larger = best_larger;
                    end
                    next_k = k + 1;
                    next_state = COMPARING;
                end else begin
                    // Comparison done
                    next_state = DONE;
                end
            end
            
            DONE: begin
                // Stay in DONE state until reset or new start
                if (start) begin
                    next_state = INIT;
                    next_i = 0;
                    next_j = 0;
                    next_k = 0;
                    next_min_diff = 32'hFFFFFFFF;
                    next_best_smaller = 0;
                    next_best_larger = 0;
                    // Reload data
                    load_data = 1'b1;
                end else begin
                    next_state = DONE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
