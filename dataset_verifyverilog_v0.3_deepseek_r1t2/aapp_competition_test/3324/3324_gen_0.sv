module stoichiometry_balancer (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] entry_value,
    input [3:0] entry_elem,
    input [4:0] entry_mol,
    input entry_valid,
    input [3:0] num_elements,
    input [4:0] num_molecules,
    output reg [9:0] coeffs [0:19],
    output reg coeffs_valid,
    output reg done
);

// State declarations
localparam [2:0] LOAD          = 3'd0;
localparam [2:0] SOLVE         = 3'd1;
localparam [2:0] FIND_SOLUTION = 3'd2;
localparam [2:0] SCALE         = 3'd3;
localparam [2:0] DONE          = 3'd4;
reg [2:0] state;

// Matrix storage
reg signed [15:0] matrix [0:9][0:19];

// Gaussian elimination variables
reg [4:0] row;
reg [4:0] col;
reg [4:0] pivot_row;
reg signed [15:0] pivot_val;
reg signed [15:0] divisor;

// Back substitution variables
reg [4:0] free_col;
reg [4:0] bound_col;
reg signed [15:0] temp;

// GCD scaling variables
reg [2:0] gcd_stage;
reg [31:0] gcd_temp_a;
reg [31:0] gcd_temp_b;

// Misc
reg [9:0] cycle_count;
reg [4:0] mol_count;
reg [3:0] elem_count;
integer i, j;

// Initialization and main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= LOAD;
        done <= 1'b0;
        coeffs_valid <= 1'b0;
        cycle_count <= 10'd0;
        
        // Clear matrix
        for (i = 0; i < 10; i = i + 1) begin
            for (j = 0; j < 20; j = j + 1) begin
                matrix[i][j] <= 16'd0;
            end
        end
        
        // Clear coefficients
        for (j = 0; j < 20; j = j + 1) begin
            coeffs[j] <= 10'd0;
        end
        
        // Reset solver variables
        row <= 5'd0;
        col <= 5'd0;
        divisor <= 16'd1;
    end
    else begin
        cycle_count <= cycle_count + 10'd1;
        
        case (state)
            LOAD: begin
                done <= 1'b0;
                coeffs_valid <= 1'b0;
                
                if (entry_valid) begin
                    if (entry_elem < 10 && entry_mol < 20) begin
                        matrix[entry_elem][entry_mol] <= entry_value;
                    end
                end
                
                if (start && !entry_valid) begin
                    state <= SOLVE;
                    row <= 5'd0;
                    col <= 5'd0;
                end
            end
            
            SOLVE: begin
                if (col < num_molecules && row < num_elements) begin
                    // Find pivot
                    if (matrix[row][col] == 0) begin
                        if (pivot_row == num_elements) begin
                            pivot_row <= row;
                            col <= col + 5'd1;
                        end
                        else if (matrix[pivot_row][col] != 0) begin
                            // Swap rows
                            for (j = 0; j < 20; j = j + 1) begin
                                temp <= matrix[row][j];
                                matrix[row][j] <= matrix[pivot_row][j];
                                matrix[pivot_row][j] <= temp;
                            end
                            pivot_val <= matrix[row][col];
                        end
                        else begin
                            pivot_row <= pivot_row + 5'd1;
                        end
                    end
                    else begin
                        pivot_val <= matrix[row][col];
                        
                        // Eliminate column below
                        for (i = row + 5'd1; i < num_elements; i = i + 1) begin
                            divisor <= (row > 0) ? matrix[row-5'd1][row-5'd1] : 16'd1;
                            matrix[i][col] <= (pivot_val * matrix[i][col] - matrix[i][row] * matrix[row][col]) / divisor;
                        end
                        
                        row <= row + 5'd1;
                        col <= col + 5'd1;
                    end
                end
                else begin
                    state <= FIND_SOLUTION;
                    free_col <= 5'd0;
                end
            end
            
            FIND_SOLUTION: begin
                // Identify free columns
                if (free_col < num_molecules) begin
                    if (matrix[free_col][free_col] == 0) begin
                        // Back-substitute
                        coeffs[free_col] <= 10'd1;
                        bound_col <= free_col + 5'd1;
                        
                        while (bound_col < num_molecules) begin
                            if (matrix[free_col][bound_col] != 0) begin
                                coeffs[bound_col] <= coeffs[bound_col] - (matrix[free_col][bound_col] * coeffs[free_col]) / matrix[free_col][free_col];
                            end
                            bound_col <= bound_col + 5'd1;
                        end
                    end
                    
                    free_col <= free_col + 5'd1;
                end
                else begin
                    state <= SCALE;
                    gcd_stage <= 3'd0;
                end
            end
            
            SCALE: begin
                case (gcd_stage)
                    0: begin
                        gcd_temp_a <= coeffs[0] > 0 ? coeffs[0] : -coeffs[0];
                        gcd_temp_b <= coeffs[1] > 0 ? coeffs[1] : -coeffs[1];
                        gcd_stage <= 3'd1;
                    end
                    1: begin
                        gcd_temp_a <= gcd_temp_b;
                        gcd_temp_b <= gcd_temp_a % gcd_temp_b;
                        gcd_stage <= (gcd_temp_b == 0) ? 3'd2 : 3'd1;
                    end
                    2: begin
                        // Scale coefficients by GCD
                        for (j = 0; j < 20; j = j + 1) begin
                            coeffs[j] <= coeffs[j] / gcd_temp_a;
                        end
                        gcd_stage <= 3'd3;
                    end
                    3: begin
                        state <= DONE;
                    end
                endcase
            end
            
            DONE: begin
                coeffs_valid <= 1'b1;
                done <= 1'b1;
                if (cycle_count > 10'd10) begin
                    state <= LOAD;
                    done <= 1'b0;
                    coeffs_valid <= 1'b0;
                end
            end
            
            default: state <= LOAD;
        endcase
    end
end

endmodule
