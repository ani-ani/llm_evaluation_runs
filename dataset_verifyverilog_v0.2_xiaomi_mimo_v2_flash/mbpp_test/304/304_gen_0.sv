module find_element_after_rotations (
    input [2:0] index_final,
    input [1:0] num_rotations,
    input [2:0] rotation_ranges_left [3:0],
    input [2:0] rotation_ranges_right [3:0],
    input [3:0][2:0] array_data,
    output reg [2:0] result
);

    integer i;
    reg [2:0] current_index;

    always @(*) begin
        current_index = index_final;
        
        // Process rotations in reverse order: from num_rotations-1 down to 0
        // We unroll the loop for the maximum possible number of rotations (4)
        
        // Undo rotation 3
        if (num_rotations > 3 && current_index >= rotation_ranges_left[3] && current_index <= rotation_ranges_right[3]) begin
            if (current_index == rotation_ranges_left[3])
                current_index = rotation_ranges_right[3];
            else
                current_index = current_index - 1;
        end
        
        // Undo rotation 2
        if (num_rotations > 2 && current_index >= rotation_ranges_left[2] && current_index <= rotation_ranges_right[2]) begin
            if (current_index == rotation_ranges_left[2])
                current_index = rotation_ranges_right[2];
            else
                current_index = current_index - 1;
        end
        
        // Undo rotation 1
        if (num_rotations > 1 && current_index >= rotation_ranges_left[1] && current_index <= rotation_ranges_right[1]) begin
            if (current_index == rotation_ranges_left[1])
                current_index = rotation_ranges_right[1];
            else
                current_index = current_index - 1;
        end
        
        // Undo rotation 0
        if (num_rotations > 0 && current_index >= rotation_ranges_left[0] && current_index <= rotation_ranges_right[0]) begin
            if (current_index == rotation_ranges_left[0])
                current_index = rotation_ranges_right[0];
            else
                current_index = current_index - 1;
        end
        
        // Map back to array_data (assuming array_data[0] maps to index 0, etc.)
        // Since array_data is a packed array [3:0][2:0], we access via index
        result = array_data[current_index];
    end

endmodule