module chemical_balancer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_valid,
    input wire [3:0] molecule_idx,
    input wire sign,
    input wire [3:0] num_elements,
    input wire [3:0] element_id,
    input wire [3:0] count,
    input wire [15:0] coeff_in,
    output reg result_valid,
    output reg [15:0] coeff_out,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG = 3'd1;
    localparam [2:0] MATRIX_BUILD = 3'd2;
    localparam [2:0] SOLVE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Configuration storage
    reg [15:0] molecule_sign; // 16 bits for 16 molecules
    reg [3:0] molecule_element_count [0:15]; // Count of elements per molecule
    reg [3:0] molecule_elements [0:15][0:9]; // Element IDs per molecule
    reg [3:0] molecule_counts [0:15][0:9]; // Counts per element per molecule
    
    // Unique elements tracking
    reg [9:0] unique_elements; // Bitmask of unique elements
    reg [3:0] num_unique_elements;
    
    // Matrix storage (10x16)
    reg signed [31:0] matrix [0:9][0:15]; // Q16.16 fixed-point
    
    // Solution storage
    reg [15:0] coefficients [0:15];
    
    // Control signals
    reg [3:0] current_molecule;
    reg [3:0] current_element;
    reg [3:0] current_row;
    reg [3:0] current_col;
    reg [3:0] pivot_row;
    reg [3:0] output_idx;
    
    // Fixed-point arithmetic helpers
    function [31:0] multiply_q16_16;
        input [31:0] a, b;
        reg [31:0] result;
        begin
            result = $signed(a) * $signed(b);
            multiply_q16_16 = result >>> 16; // Rounding shift
        end
    endfunction
    
    function [31:0] divide_q16_16;
        input [31:0] a, b;
        reg [31:0] result;
        begin
            if (b == 32'd0) begin
                divide_q16_16 = 32'd0;
            end else begin
                result = ($signed(a) << 16) / $signed(b);
                divide_q16_16 = result;
            end
        end
    endfunction
    
    // GCD calculation
    function [15:0] gcd;
        input [15:0] a, b;
        reg [15:0] x, y, temp;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                temp = y;
                y = x % y;
                x = temp;
            end
            gcd = x;
        end
    endfunction
    
    // LCM calculation
    function [15:0] lcm;
        input [15:0] a, b;
        begin
            if (a == 0 || b == 0)
                lcm = 0;
            else
                lcm = (a / gcd(a, b)) * b;
        end
    endfunction
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            done <= 1'b0;
            coeff_out <= 16'd0;
            
            // Reset all storage
            molecule_sign <= 16'd0;
            current_molecule <= 4'd0;
            current_element <= 4'd0;
            num_unique_elements <= 4'd0;
            unique_elements <= 10'd0;
            
            // Initialize matrix
            integer i, j;
            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    matrix[i][j] <= 32'd0;
                end
            end
            
            // Initialize coefficients
            for (i = 0; i < 16; i = i + 1) begin
                coefficients[i] <= 16'd0;
            end
            
            output_idx <= 4'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = CONFIG;
            end
            
            CONFIG: begin
                if (config_valid && current_element == num_elements) begin
                    if (current_molecule == 15) begin
                        next_state = MATRIX_BUILD;
                    end else begin
                        current_molecule <= current_molecule + 1;
                        current_element <= 0;
                    end
                end
            end
            
            MATRIX_BUILD: begin
                if (current_row == num_unique_elements - 1 && current_col == 15) begin
                    next_state = SOLVE;
                end
            end
            
            SOLVE: begin
                if (current_col == 15 && current_row == num_unique_elements - 1) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                if (output_idx == 15) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Configuration phase logic
    always @(posedge clk) begin
        if (state == CONFIG && config_valid) begin
            // Store molecule sign
            if (current_element == 0) begin
                molecule_sign[current_molecule] <= sign;
                molecule_element_count[current_molecule] <= num_elements;
            end
            
            // Store element data
            if (current_element < num_elements) begin
                molecule_elements[current_molecule][current_element] <= element_id;
                molecule_counts[current_molecule][current_element] <= count;
                
                // Track unique elements
                if (!$bitstoreal(unique_elements[element_id])) begin
                    unique_elements[element_id] <= 1'b1;
                    num_unique_elements <= num_unique_elements + 1;
                end
                
                current_element <= current_element + 1;
            end
        end
    end
    
    // Matrix building phase
    always @(posedge clk) begin
        if (state == MATRIX_BUILD) begin
            // Build matrix row by row
            if (current_col < 16) begin
                // Get the sign for this molecule
                reg molecule_s = molecule_sign[current_col];
                
                // For each element in this molecule
                reg [3:0] elem_idx;
                for (elem_idx = 0; elem_idx < molecule_element_count[current_col]; elem_idx = elem_idx + 1) begin
                    reg [3:0] eid = molecule_elements[current_col][elem_idx];
                    reg [3:0] cnt = molecule_counts[current_col][elem_idx];
                    
                    // Find the row for this element
                    reg [3:0] row;
                    reg [3:0] found;
                    for (row = 0; row < 10; row = row + 1) begin
                        if (unique_elements[row] && row == eid) begin
                            found = 1'b1;
                            break;
                        end
                    end
                    
                    if (found) begin
                        // Store in matrix (Q16.16 format)
                        matrix[row][current_col] <= (molecule_s ? -cnt : cnt) << 16;
                    end
                end
                
                current_col <= current_col + 1;
            else begin
                current_col <= 0;
                current_row <= current_row + 1;
            end
        end
    end
    
    // Solving phase (Gauss-Jordan elimination)
    always @(posedge clk) begin
        if (state == SOLVE) begin
            // Find pivot
            if (current_col < 16 && current_row < num_unique_elements) begin
                reg [3:0] i;
                reg found_pivot;
                
                // Find first non-zero in current column
                for (i = current_row; i < num_unique_elements; i = i + 1) begin
                    if (matrix[i][current_col] != 32'd0) begin
                        pivot_row <= i;
                        found_pivot = 1'b1;
                        break;
                    end
                end
                
                if (found_pivot) begin
                    // Swap rows if needed
                    if (pivot_row != current_row) begin
                        reg [3:0] j;
                        for (j = 0; j < 16; j = j + 1) begin
                            reg signed [31:0] temp = matrix[current_row][j];
                            matrix[current_row][j] <= matrix[pivot_row][j];
                            matrix[pivot_row][j] <= temp;
                        end
                    end
                    
                    // Normalize pivot row
                    reg signed [31:0] pivot_val = matrix[current_row][current_col];
                    reg [3:0] j;
                    for (j = 0; j < 16; j = j + 1) begin
                        matrix[current_row][j] <= divide_q16_16(matrix[current_row][j], pivot_val);
                    end
                    
                    // Eliminate other rows
                    for (i = 0; i < num_unique_elements; i = i + 1) begin
                        if (i != current_row && matrix[i][current_col] != 32'd0) begin
                            reg signed [31:0] factor = matrix[i][current_col];
                            for (j = 0; j < 16; j = j + 1) begin
                                matrix[i][j] <= matrix[i][j] - multiply_q16_16(factor, matrix[current_row][j]);
                            end
                        end
                    end
                    
                    current_col <= current_col + 1;
                    current_row <= current_row + 1;
                end else begin
                    current_col <= current_col + 1;
                end
            end
            
            // After elimination, extract solution
            if (current_col == 16 && current_row == num_unique_elements) begin
                // Find the free variable (last column)
                reg [15:0] lcm_val = 1;
                reg [3:0] i;
                
                // Find denominators and compute LCM
                for (i = 0; i < num_unique_elements; i = i + 1) begin
                    reg [31:0] val = matrix[i][15];
                    reg [15:0] denom = val[15:0]; // Fractional part
                    if (denom != 0)
                        lcm_val = lcm(lcm_val, denom);
                end
                
                // Scale coefficients
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < num_unique_elements) begin
                        reg [31:0] val = matrix[i][15];
                        reg [15:0] scaled = (val >>> 16) * lcm_val;
                        coefficients[i] <= scaled;
                    end else begin
                        coefficients[i] <= lcm_val;
                    end
                end
                
                // Find GCD of all coefficients
                reg [15:0] gcd_val = coefficients[0];
                for (i = 1; i < 16; i = i + 1) begin
                    gcd_val = gcd(gcd_val, coefficients[i]);
                end
                
                // Normalize
                if (gcd_val != 0) begin
                    for (i = 0; i < 16; i = i + 1) begin
                        coefficients[i] <= coefficients[i] / gcd_val;
                    end
                end
            end
        end
    end
    
    // Output phase
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            result_valid <= 1'b1;
            coeff_out <= coefficients[output_idx];
            
            if (output_idx == 15) begin
                done <= 1'b1;
            end else begin
                output_idx <= output_idx + 1;
            end
        end else begin
            result_valid <= 1'b0;
            done <= 1'b0;
        end
    end

endmodule