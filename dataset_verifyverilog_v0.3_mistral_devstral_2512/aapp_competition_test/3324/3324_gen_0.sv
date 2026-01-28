module stoichiometry_balancer(
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

    // Parameters
    localparam [3:0] MAX_ELEMENTS = 4'd10;
    localparam [4:0] MAX_MOLECULES = 5'd20;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SOLVE = 3'd2;
    localparam [2:0] FIND_SOLUTION = 3'd3;
    localparam [2:0] SCALE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Matrix storage
    reg signed [15:0] matrix [0:9][0:19];
    reg [3:0] current_elem;
    reg [4:0] current_mol;

    // Solution vector
    reg signed [15:0] solution [0:19];

    // GCD computation
    reg [15:0] gcd_a, gcd_b, gcd_temp;
    reg [2:0] gcd_state;
    localparam [2:0] GCD_IDLE = 3'd0;
    localparam [2:0] GCD_COMPUTE = 3'd1;
    localparam [2:0] GCD_DONE = 3'd2;

    // Control signals
    reg load_complete;
    reg solve_complete;
    reg solution_found;
    reg scale_complete;

    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_elem <= 4'd0;
            current_mol <= 5'd0;
            load_complete <= 1'b0;
            solve_complete <= 1'b0;
            solution_found <= 1'b0;
            scale_complete <= 1'b0;
            coeffs_valid <= 1'b0;
            done <= 1'b0;
            gcd_state <= GCD_IDLE;
            gcd_a <= 16'd0;
            gcd_b <= 16'd0;
            gcd_temp <= 16'd0;

            // Initialize matrix
            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 20; j = j + 1) begin
                    matrix[i][j] <= 16'd0;
                end
            end

            // Initialize solution vector
            for (j = 0; j < 20; j = j + 1) begin
                solution[j] <= 16'd0;
            end

            // Initialize coefficients
            for (j = 0; j < 20; j = j + 1) begin
                coeffs[j] <= 10'd0;
            end
        end else begin
            state <= next_state;

            // State machine logic
            case (state)
                IDLE: begin
                    coeffs_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    if (entry_valid) begin
                        matrix[entry_elem][entry_mol] <= entry_value;
                        current_elem <= entry_elem;
                        current_mol <= entry_mol;
                    end
                    if (current_mol == num_molecules - 1 && current_elem == num_elements - 1) begin
                        load_complete <= 1'b1;
                        next_state <= SOLVE;
                    end
                end

                SOLVE: begin
                    // Gaussian elimination
                    reg [4:0] j;
                    reg [3:0] i;
                    reg [4:0] k;
                    reg signed [15:0] pivot_value;
                    reg signed [15:0] temp_value;
                    reg signed [31:0] temp_product;

                    // Perform elimination for each column
                    if (cycle_count < MAX_CYCLES) begin
                        j = cycle_count[7:3];
                        if (j < num_molecules - 1) begin
                            // Find pivot
                            i = j;
                            while (i < num_elements && matrix[i][j] == 16'd0) begin
                                i = i + 1;
                            end

                            // Swap rows if needed
                            if (i != j && i < num_elements) begin
                                for (k = 0; k < num_molecules; k = k + 1) begin
                                    temp_value = matrix[j][k];
                                    matrix[j][k] = matrix[i][k];
                                    matrix[i][k] = temp_value;
                                end
                            end

                            // Eliminate below pivot
                            if (i < num_elements) begin
                                pivot_value = matrix[j][j];
                                for (i = j + 1; i < num_elements; i = i + 1) begin
                                    if (matrix[i][j] != 16'd0) begin
                                        for (k = j; k < num_molecules; k = k + 1) begin
                                            temp_product = $signed(matrix[i][k]) * $signed(pivot_value);
                                            temp_product = temp_product - ($signed(matrix[i][j]) * $signed(matrix[j][k]));
                                            matrix[i][k] = temp_product[31:16];
                                        end
                                    end
                                end
                            end

                            cycle_count <= cycle_count + 8'd1;
                            if (j == num_molecules - 2) begin
                                solve_complete <= 1'b1;
                                next_state <= FIND_SOLUTION;
                            end
                        end else begin
                            solve_complete <= 1'b1;
                            next_state <= FIND_SOLUTION;
                        end
                    end else begin
                        solve_complete <= 1'b1;
                        next_state <= FIND_SOLUTION;
                    end
                end

                FIND_SOLUTION: begin
                    // Identify free variables and back-substitute
                    reg [4:0] free_var;
                    reg [4:0] bound_var;
                    reg signed [15:0] sum;

                    // Find last free variable
                    free_var = num_molecules - 1;
                    while (free_var > 0 && matrix[free_var][free_var] != 16'd0) begin
                        free_var = free_var - 1;
                    end

                    // Set free variable to 1
                    solution[free_var] <= 16'd1;

                    // Back-substitute
                    for (bound_var = num_molecules - 1; bound_var >= 0; bound_var = bound_var - 1) begin
                        if (matrix[bound_var][bound_var] != 16'd0) begin
                            sum = 16'd0;
                            for (free_var = bound_var + 1; free_var < num_molecules; free_var = free_var + 1) begin
                                sum = sum + $signed(matrix[bound_var][free_var]) * $signed(solution[free_var]);
                            end
                            solution[bound_var] <= -sum / matrix[bound_var][bound_var];
                        end
                    end

                    solution_found <= 1'b1;
                    next_state <= SCALE;
                end

                SCALE: begin
                    // Compute GCD of all coefficients
                    reg [15:0] current_gcd;
                    reg [4:0] coeff_idx;

                    // Initialize GCD with first non-zero coefficient
                    coeff_idx = 0;
                    while (coeff_idx < num_molecules && solution[coeff_idx] == 16'd0) begin
                        coeff_idx = coeff_idx + 1;
                    end

                    if (coeff_idx < num_molecules) begin
                        current_gcd = solution[coeff_idx];
                        gcd_a <= current_gcd;
                        gcd_state <= GCD_COMPUTE;

                        // Compute GCD for remaining coefficients
                        for (coeff_idx = coeff_idx + 1; coeff_idx < num_molecules; coeff_idx = coeff_idx + 1) begin
                            if (solution[coeff_idx] != 16'd0) begin
                                gcd_b <= solution[coeff_idx];
                                gcd_state <= GCD_COMPUTE;
                                while (gcd_state != GCD_DONE) begin
                                    // Wait for GCD computation
                                end
                                current_gcd = gcd_a;
                                gcd_a <= current_gcd;
                            end
                        end

                        // Scale coefficients
                        for (coeff_idx = 0; coeff_idx < num_molecules; coeff_idx = coeff_idx + 1) begin
                            if (current_gcd != 16'd0) begin
                                coeffs[coeff_idx] <= $signed(solution[coeff_idx]) / current_gcd;
                            end else begin
                                coeffs[coeff_idx] <= solution[coeff_idx];
                            end
                        end

                        scale_complete <= 1'b1;
                        next_state <= DONE_STATE;
                    end else begin
                        scale_complete <= 1'b1;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    coeffs_valid <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // GCD computation state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_state <= GCD_IDLE;
        end else begin
            case (gcd_state)
                GCD_IDLE: begin
                    // Wait for input
                end

                GCD_COMPUTE: begin
                    if (gcd_b == 16'd0) begin
                        gcd_a <= gcd_a;
                        gcd_state <= GCD_DONE;
                    end else begin
                        gcd_temp <= gcd_a % gcd_b;
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_temp;
                    end
                end

                GCD_DONE: begin
                    // Wait for next computation
                end

                default: begin
                    gcd_state <= GCD_IDLE;
                end
            endcase
        end
    end

endmodule