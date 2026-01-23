module minimal_max_sum (
    input clk,
    input rst_n,
    input start,
    input [6:0] a_in,
    input [6:0] b_in,
    input data_valid,
    output reg [7:0] result,
    output reg done,
    output reg error
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam COLLECT = 3'b001;
    localparam SORT_A = 3'b010;
    localparam SORT_B = 3'b011;
    localparam CALCULATE = 3'b100;
    localparam DONE = 3'b101;

    // Registers for state and data
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Arrays to store inputs (8 elements)
    reg [6:0] arr_a [0:7];
    reg [6:0] arr_b [0:7];
    
    // Counter for different operations
    reg [2:0] idx;           // Index for bubble sort and max calculation
    reg [2:0] count;         // Number of elements collected
    reg [2:0] pass_count;    // Track bubble sort passes
    
    // Temporary swap registers
    reg [6:0] temp_a;
    reg [6:0] temp_b;
    
    // Max calculation temp register
    reg [7:0] current_sum;
    
    // Counter for timing (used in CALCULATE state)
    reg [2:0] calc_idx;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic (Moore style)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 8'b0;
            done <= 1'b0;
            error <= 1'b0;
            count <= 3'b0;
            idx <= 3'b0;
            pass_count <= 3'b0;
            calc_idx <= 3'b0;
            temp_a <= 7'b0;
            temp_b <= 7'b0;
            current_sum <= 8'b0;
            // Clear arrays
            for (integer i = 0; i < 8; i = i + 1) begin
                arr_a[i] <= 7'b0;
                arr_b[i] <= 7'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    count <= 3'b0;
                    idx <= 3'b0;
                    pass_count <= 3'b0;
                    calc_idx <= 3'b0;
                    if (start) begin
                        // Start signal received, wait for data
                        // Stay in IDLE or transition to COLLECT depends on design
                        // We'll transition to COLLECT on next cycle
                    end
                end
                
                COLLECT: begin
                    if (data_valid) begin
                        if (count < 3'd8) begin
                            arr_a[count] <= a_in;
                            arr_b[count] <= b_in;
                            count <= count + 1'b1;
                            error <= 1'b0;
                        end else begin
                            // More than 8 values provided
                            error <= 1'b1;
                        end
                    end
                    // Reset index for sorting
                    idx <= 3'b0;
                    pass_count <= 3'b0;
                end
                
                SORT_A: begin
                    // Bubble sort ascending for array A
                    if (idx < count - 1'b1) begin
                        if (arr_a[idx] > arr_a[idx + 1'b1]) begin
                            // Swap
                            temp_a <= arr_a[idx];
                            arr_a[idx] <= arr_a[idx + 1'b1];
                            arr_a[idx + 1'b1] <= temp_a;
                        end
                        idx <= idx + 1'b1;
                    end else begin
                        // End of pass
                        if (pass_count < count - 1'b1) begin
                            pass_count <= pass_count + 1'b1;
                            idx <= 3'b0;
                        end
                    end
                end
                
                SORT_B: begin
                    // Bubble sort descending for array B
                    if (idx < count - 1'b1) begin
                        if (arr_b[idx] < arr_b[idx + 1'b1]) begin
                            // Swap (descending order)
                            temp_b <= arr_b[idx];
                            arr_b[idx] <= arr_b[idx + 1'b1];
                            arr_b[idx + 1'b1] <= temp_b;
                        end
                        idx <= idx + 1'b1;
                    end else begin
                        // End of pass
                        if (pass_count < count - 1'b1) begin
                            pass_count <= pass_count + 1'b1;
                            idx <= 3'b0;
                        end
                    end
                end
                
                CALCULATE: begin
                    // Calculate max sum: A[i] + B[i]
                    if (calc_idx == 3'b0) begin
                        current_sum <= arr_a[0] + arr_b[0];
                        calc_idx <= 3'b1;
                    end else if (calc_idx < count) begin
                        if (arr_a[calc_idx] + arr_b[calc_idx] > current_sum) begin
                            current_sum <= arr_a[calc_idx] + arr_b[calc_idx];
                        end
                        calc_idx <= calc_idx + 1'b1;
                    end
                end
                
                DONE: begin
                    result <= current_sum;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COLLECT;
                else
                    next_state = IDLE;
            end
            
            COLLECT: begin
                // Wait until we have 8 pairs or enough data
                // If data_valid goes low and we have data, transition
                // For simplicity, transition after count reaches 8 or if not collecting
                if (!data_valid && count > 0)
                    next_state = SORT_A;
                else if (count == 3'd8)
                    next_state = SORT_A;
                else
                    next_state = COLLECT;
            end
            
            SORT_A: begin
                // Check if bubble sort is complete for array A
                // Bubble sort needs (count-1) passes, each pass needs (count-1) comparisons
                // We use pass_count to track passes and idx for comparisons within a pass
                if (pass_count >= count - 1'b1 && idx >= count - 1'b1)
                    next_state = SORT_B;
                else
                    next_state = SORT_A;
            end
            
            SORT_B: begin
                // Check if bubble sort is complete for array B
                if (pass_count >= count - 1'b1 && idx >= count - 1'b1)
                    next_state = CALCULATE;
                else
                    next_state = SORT_B;
            end
            
            CALCULATE: begin
                // Calculation done when calc_idx reaches count
                if (calc_idx >= count)
                    next_state = DONE;
                else
                    next_state = CALCULATE;
            end
            
            DONE: begin
                // Stay in DONE until reset or start again
                if (start)
                    next_state = COLLECT;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
