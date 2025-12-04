module monotonic_checker (
    input [7:0] array_in [7:0],
    input [2:0] actual_elements,
    output wire is_monotonic
);

// Internal wires for comparison vectors
wire [6:0] non_decreasing_vec;
wire [6:0] non_increasing_vec;
wire non_decreasing;
wire non_increasing;

// Generate comparisons for all adjacent pairs
generate
    genvar i;
    for (i = 0; i < 7; i++) begin : compare
        // For non-decreasing: check if current element <= next element
        assign non_decreasing_vec[i] = (i+1 < actual_elements) ? (array_in[i] <= array_in[i+1]) : 1'b1;
        // For non-increasing: check if current element >= next element
        assign non_increasing_vec[i] = (i+1 < actual_elements) ? (array_in[i] >= array_in[i+1]) : 1'b1;
    end
endgenerate

// Reduction AND to combine all comparisons
assign non_decreasing = &non_decreasing_vec;
assign non_increasing = &non_increasing_vec;

// Final monotonic check (either non-decreasing or non-increasing)
assign is_monotonic = non_decreasing || non_increasing;

endmodule