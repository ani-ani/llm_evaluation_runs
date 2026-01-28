module stoichiometry_balancer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] entry_value,
    input wire [3:0] entry_elem,
    input wire [4:0] entry_mol,
    input wire entry_valid,
    input wire [3:0] num_elements,
    input wire [4:0] num_molecules,
    output reg [9:0] coeffs [0:19],
    output reg coeffs_valid,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_ELEMENTS = 4'd10;
    localparam [4:0] MAX_MOLECULES = 5'd20;
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SOLVE     = 3'd2;
    localparam [2:0] FIND_SOLUTION = 3'd3;
    localparam [2:0] SCALE     = 3'd4;
    localparam [2:0] DONE      = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Matrix storage - [element][molecule]
    reg signed [15:0] matrix [0:9] [0:19];
    
    // Solution coefficients
    reg [9:0] solution [0:19];
    reg [9:0] gcd_value;
    
    // Control signals
    reg [3:0] elem_idx;
    reg [4:0] mol_idx;
    reg [3:0] pivot_row;
    reg [4:0] pivot_col;
    reg [3:0] row_idx;
    reg [4:0] col_idx;
    reg [3:0] free_idx;
    reg [3:0] back_row;
    reg [4:0] back_col;
    reg [3:0] gcd_idx;
    
    // GCD computation
    reg [9:0] gcd_a;
    reg [9:0] gcd_b;
    reg [9:0] gcd_temp;
    reg [1:0] gcd_state;
    localparam [1:0] GCD_IDLE = 2'd0;
    localparam [1:0] GCD_COMPUTE = 2'd1;
    localparam [1:0] GCD_DONE = 2'd2;
    
    // Null space vector
    reg signed [15:0] null_vector [0:19];
    
    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    integer i, j;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Initialize all registers
            coeffs_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            elem_idx <= 4'd0;
            mol_idx <= 5'd0;
            pivot_row <= 4'd0;
            pivot_col <= 5'd0;
            row_idx <= 4'd0;
            col_idx <= 5'd0;
            free_idx <= 4'd0;
            back_row <= 4'd0;
            back_col <= 5'd0;
            gcd_idx <= 4'd0;
            gcd_a <= 10'd0;
            gcd_b <= 10'd0;
            gcd_value <= 10'd0;
            gcd_state <= GCD_IDLE;
            
            // Initialize matrix
            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 20; j = j + 1) begin
                    matrix[i][j] <= 16'sd0;
                end
            end
            
            // Initialize solution and null vector
            for (j = 0; j < 20; j = j + 1) begin
                solution[j] <= 10'd0;
                null_vector[j] <= 16'sd0;
                coeffs[j] <= 10'd0;
            end
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    coeffs_valid <= 1'b0;
                    cycle_count <= 10'd0;
                    if (entry_valid) begin
                        // Direct load on entry_valid
                        matrix[entry_elem][entry_mol] <= entry_value;
                    end
                end
                
                LOAD: begin
                    if (entry_valid) begin
                        matrix[entry_elem][entry_mol] <= entry_value;
                    end
                end
                
                SOLVE: begin
                    cycle_count <= cycle_count + 10'd1;
                    // Fraction-free Gaussian elimination
                    if (pivot_col < num_molecules - 5'd1 && pivot_row < num_elements) begin
                        // Find pivot
                        if (matrix[pivot_row][pivot_col] == 16'sd0) begin
                            // Search for non-zero in current column
                            if (row_idx < num_elements) begin
                                if (matrix[row_idx][pivot_col] != 16'sd0 && row_idx >= pivot_row) begin
                                    // Swap rows
                                    for (j = 0; j < 20; j = j + 1) begin
                                        matrix[pivot_row][j] <= matrix[row_idx][j];
                                        matrix[row_idx][j] <= matrix[pivot_row][j];
                                    end
                                    pivot_row <= pivot_row + 4'd1;
                                    row_idx <= 4'd0;
                                end else begin
                                    row_idx <= row_idx + 4'd1;
                                end
                            end else begin
                                // No pivot found, advance column
                                pivot_col <= pivot_col + 5'd1;
                                row_idx <= 4'd0;
                            end
                        end else begin
                            // Pivot found, eliminate below
                            if (row_idx < num_elements && row_idx != pivot_row) begin
                                if (matrix[row_idx][pivot_col] != 16'sd0) begin
                                    // Bareiss elimination
                                    for (col_idx = pivot_col + 5'd1; col_idx < num_molecules; col_idx = col_idx + 5'd1) begin
                                        matrix[row_idx][col_idx] <= (matrix[row_idx][col_idx] * matrix[pivot_row][pivot_col] - matrix[row_idx][pivot_col] * matrix[pivot_row][col_idx]) / 16'sd1;
                                    end
                                    matrix[row_idx][pivot_col] <= 16'sd0;
                                end
                                row_idx <= row_idx + 4'd1;
                            end else begin
                                pivot_row <= pivot_row + 4'd1;
                                pivot_col <= pivot_col + 5'd1;
                                row_idx <= pivot_row + 4'd1;
                            end
                        end
                    end
                end
                
                FIND_SOLUTION: begin
                    // Set null vector
                    if (free_idx < num_molecules) begin
                        if (pivot_col < num_molecules && free_idx == pivot_col) begin
                            // Bound variable, will compute from back-substitution
                            null_vector[free_idx] <= 16'sd0;
                        end else begin
                            // Free variable
                            if (free_idx == num_molecules - 5'd1) begin
                                null_vector[free_idx] <= 16'sd1;  // Set last free to 1
                            end else begin
                                null_vector[free_idx] <= 16'sd0;
                            end
                        end
                        free_idx <= free_idx + 5'd1;
                    end else begin
                        // Back-substitution
                        if (back_row > 4'd0 && back_row <= num_elements) begin
                            if (back_col < num_molecules) begin
                                if (matrix[back_row-4'd1][back_col] != 16'sd0 && back_col < num_molecules - 5'd1) begin
                                    // Compute bound variable
                                    reg signed [15:0] sum;
                                    sum = 16'sd0;
                                    for (j = back_col + 5'd1; j < num_molecules; j = j + 5'd1) begin
                                        sum = sum + matrix[back_row-4'd1][j] * null_vector[j];
                                    end
                                    null_vector[back_col] <= -sum / matrix[back_row-4'd1][back_col];
                                end
                                back_col <= back_col + 5'd1;
                            end else begin
                                back_col <= 5'd0;
                                back_row <= back_row - 4'd1;
                            end
                        end
                    end
                end
                
                SCALE: begin
                    // GCD computation pipeline
                    case (gcd_state)
                        GCD_IDLE: begin
                            if (gcd_idx < num_molecules) begin
                                if (null_vector[gcd_idx] != 16'sd0) begin
                                    gcd_a <= (null_vector[gcd_idx] > 0) ? null_vector[gcd_idx] : -null_vector[gcd_idx];
                                    gcd_b <= gcd_value;
                                    gcd_state <= GCD_COMPUTE;
                                end
                                gcd_idx <= gcd_idx + 5'd1;
                            end else begin
                                gcd_state <= GCD_DONE;
                            end
                        end
                        GCD_COMPUTE: begin
                            if (gcd_b == 10'd0) begin
                                gcd_value <= gcd_a;
                                gcd_state <= GCD_IDLE;
                            end else begin
                                gcd_temp <= gcd_b;
                                gcd_b <= gcd_a % gcd_b;
                                gcd_a <= gcd_temp;
                            end
                        end
                        GCD_DONE: begin
                            // Divide by GCD
                            if (gcd_idx < num_molecules && gcd_value != 10'd0) begin
                                solution[gcd_idx] <= (null_vector[gcd_idx] > 0) ? (null_vector[gcd_idx] / gcd_value) : 10'd0;
                                coeffs[gcd_idx] <= (null_vector[gcd_idx] > 0) ? (null_vector[gcd_idx] / gcd_value) : 10'd0;
                                gcd_idx <= gcd_idx + 5'd1;
                            end
                        end
                    endcase
                end
                
                DONE: begin
                    done <= 1'b1;
                    coeffs_valid <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                if (!entry_valid && cycle_count > 10'd0) begin
                    next_state = SOLVE;
                end
            end
            
            SOLVE: begin
                if ((pivot_col >= num_molecules - 5'd1) || (cycle_count >= MAX_CYCLES)) begin
                    next_state = FIND_SOLUTION;
                end
            end
            
            FIND_SOLUTION: begin
                if (back_row <= 4'd0 && free_idx >= num_molecules) begin
                    next_state = SCALE;
                end
            end
            
            SCALE: begin
                if (gcd_state == GCD_DONE && gcd_idx >= num_molecules) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule