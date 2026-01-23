module find_element_after_rotations (
  input [2:0] index_final, 
  input [1:0] num_rotations, 
  input [2:0] rotation_ranges_left [3:0], 
  input [2:0] rotation_ranges_right [3:0], 
  input [3:0][2:0] array_data, 
  output reg [2:0] result 
);

always @(*) begin
    reg [2:0] current_index;
    current_index = index_final;

    // Process rotations in reverse order, from highest index down to 0, but only up to num_rotations-1
    
    if (num_rotations > 2) begin
        [2:0] left = rotation_ranges_left[2];
        [2:0] right = rotation_ranges_right[2];
        if (current_index >= left && current_index <= right) begin
            if (current_index == left) begin
                current_index = right;
            end else begin
                current_index = current_index -1;
            end
        end
    end

    if (num_rotations >1) begin
        [2:0] left = rotation_ranges_left[1];
        [2:0] right = rotation_ranges_right[1];
        if (current_index >= left && current_index <= right) begin
            if (current_index == left) begin
                current_index = right;
            end else begin
                current_index = current_index -1;
            end
        end
    end

    if (num_rotations >0) begin
        [2:0] left = rotation_ranges_left[0];
        [2:0] right = rotation_ranges_right[0];
        if (current_index >= left && current_index <= right) begin
            if (current_index == left) begin
                current_index = right;
            end else begin
                current_index = current_index -1;
            end
        end
    end

    result = array_data[current_index];
end
endmodule