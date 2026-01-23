module sort_third(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in [7:0],
    output reg [7:0] data_out [7:0],
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_SORT = 3'b001;
    localparam SWAP = 3'b010;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal array storage (signed to handle comparison correctly)
    reg signed [7:0] arr [7:0];
    reg signed [7:0] next_arr [7:0];
    
    // Sorting indices: 0, 3, 6
    // We use a pointer to track which pair we are comparing
    // ptr 0: compare index 0 and 3
    // ptr 1: compare index 3 and 6
    // ptr 2: compare index 0 and 3 (second pass to ensure 0 is smallest)
    reg [1:0] sort_ptr;
    reg [1:0] next_sort_ptr;
    
    // Bubble sort flag to track if any swap occurred
    reg swapped;
    reg next_swapped;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sort_ptr <= 2'b00;
            swapped <= 1'b0;
        end else begin
            state <= next_state;
            sort_ptr <= next_sort_ptr;
            swapped <= next_swapped;
            // Update array contents
            arr <= next_arr;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_sort_ptr = sort_ptr;
        next_swapped = swapped;
        
        // Default next array keeps current values
        for (int i = 0; i < 8; i++) begin
            next_arr[i] = arr[i];
        end

        case (state)
            IDLE: begin
                if (start) begin
                    // Load input array into internal storage
                    next_arr = data_in;
                    next_sort_ptr = 2'b00;
                    next_swapped = 1'b0;
                    next_state = CHECK_SORT;
                end
            end

            CHECK_SORT: begin
                // Determine which pair to compare based on sort_ptr
                // Indices: 0, 3, 6
                if (sort_ptr == 2'b00) begin
                    // Compare index 0 and 3
                    if (arr[0] > arr[3]) begin
                        next_swapped = 1'b1;
                        next_state = SWAP;
                    end else begin
                        next_sort_ptr = 2'b01;
                        next_state = CHECK_SORT;
                    end
                end else if (sort_ptr == 2'b01) begin
                    // Compare index 3 and 6
                    if (arr[3] > arr[6]) begin
                        next_swapped = 1'b1;
                        next_state = SWAP;
                    end else begin
                        next_sort_ptr = 2'b10;
                        next_state = CHECK_SORT;
                    end
                end else if (sort_ptr == 2'b10) begin
                    // Final check: compare index 0 and 3 again
                    if (arr[0] > arr[3]) begin
                        next_swapped = 1'b1;
                        next_state = SWAP;
                    end else begin
                        // Sorting complete if no swaps in last pass
                        next_state = DONE;
                    end
                end else begin
                    next_state = DONE; // Fallback
                end
            end

            SWAP: begin
                // Perform swap based on sort_ptr
                if (sort_ptr == 2'b00) begin
                    next_arr[0] = arr[3];
                    next_arr[3] = arr[0];
                end else if (sort_ptr == 2'b01) begin
                    next_arr[3] = arr[6];
                    next_arr[6] = arr[3];
                end else if (sort_ptr == 2'b10) begin
                    next_arr[0] = arr[3];
                    next_arr[3] = arr[0];
                end
                
                // Move to next check, reset swapped flag for next pass evaluation
                // Actually, for strict bubble sort, we increment pointer or loop back
                // Simplification: Advance pointer
                if (sort_ptr < 2'b10) begin
                    next_sort_ptr = sort_ptr + 1'b1;
                    next_state = CHECK_SORT;
                end else begin
                    // After final swap, check again
                    next_state = CHECK_SORT;
                    next_sort_ptr = 2'b00; // Restart pass to ensure stability
                end
                next_swapped = 1'b0;
            end

            DONE: begin
                // Hold state until reset or start
                if (!start) begin
                    // Wait for start to go low (optional, but good practice)
                end else begin
                    // Restart if start is still high or pulsed
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        data_out = arr;
        done = (state == DONE);
    end

endmodule
