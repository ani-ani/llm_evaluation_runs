module challenge24 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a, b, c, d,
    output reg [7:0] grade,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE = 4'd1;
    localparam [3:0] FINISH = 4'd2;

    // Expression tree patterns (5 total)
    localparam [2:0] TREE1 = 3'd0;  // ((a op b) op c) op d
    localparam [2:0] TREE2 = 3'd1;  // (a op (b op c)) op d
    localparam [2:0] TREE3 = 3'd2;  // a op ((b op c) op d)
    localparam [2:0] TREE4 = 3'd3;  // a op (b op (c op d))
    localparam [2:0] TREE5 = 3'd4;  // (a op b) op (c op d)

    // Operator definitions
    localparam [2:0] ADD = 3'd0;
    localparam [2:0] SUB = 3'd1;
    localparam [2:0] MUL = 3'd2;
    localparam [2:0] DIV = 3'd3;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Counters for permutations and operators
    reg [4:0] perm_counter;  // 0-23 (24 permutations)
    reg [5:0] op_counter;    // 0-63 (64 operator combinations)
    reg [2:0] tree_counter;  // 0-4 (5 trees)

    // Current permutation indices
    reg [1:0] p0, p1, p2, p3;

    // Current operators
    reg [2:0] op1, op2, op3;

    // Current tree
    reg [2:0] current_tree;

    // Intermediate results
    reg signed [15:0] temp1, temp2, temp3, temp4, temp5, temp6, temp7, temp8, temp9, temp10;
    reg signed [15:0] result1, result2, result3, result4, result5;

    // Current grade calculation
    reg [7:0] current_grade;
    reg [7:0] min_grade;
    reg found;

    // Permutation lookup table (24 permutations of 0,1,2,3)
    reg [1:0] perm_table [0:23];
    integer i;

    // Initialize permutation table
    initial begin
        // Predefined permutation table
        perm_table[0] = 2'd0; perm_table[1] = 2'd1; perm_table[2] = 2'd2; perm_table[3] = 2'd3;
        perm_table[4] = 2'd0; perm_table[5] = 2'd1; perm_table[6] = 2'd3; perm_table[7] = 2'd2;
        perm_table[8] = 2'd0; perm_table[9] = 2'd2; perm_table[10] = 2'd1; perm_table[11] = 2'd3;
        perm_table[12] = 2'd0; perm_table[13] = 2'd2; perm_table[14] = 2'd3; perm_table[15] = 2'd1;
        perm_table[16] = 2'd0; perm_table[17] = 2'd3; perm_table[18] = 2'd1; perm_table[19] = 2'd2;
        perm_table[20] = 2'd0; perm_table[21] = 2'd3; perm_table[22] = 2'd2; perm_table[23] = 2'd1;
        perm_table[24] = 2'd1; perm_table[25] = 2'd0; perm_table[26] = 2'd2; perm_table[27] = 2'd3;
        perm_table[28] = 2'd1; perm_table[29] = 2'd0; perm_table[30] = 2'd3; perm_table[31] = 2'd2;
        perm_table[32] = 2'd1; perm_table[33] = 2'd2; perm_table[34] = 2'd0; perm_table[35] = 2'd3;
        perm_table[36] = 2'd1; perm_table[37] = 2'd2; perm_table[38] = 2'd3; perm_table[39] = 2'd0;
        perm_table[40] = 2'd1; perm_table[41] = 2'd3; perm_table[42] = 2'd0; perm_table[43] = 2'd2;
        perm_table[44] = 2'd1; perm_table[45] = 2'd3; perm_table[46] = 2'd2; perm_table[47] = 2'd0;
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            grade <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            perm_counter <= 5'd0;
            op_counter <= 6'd0;
            tree_counter <= 3'd0;
            found <= 1'b0;
            min_grade <= 8'd255;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        perm_counter <= 5'd0;
                        op_counter <= 6'd0;
                        tree_counter <= 3'd0;
                        found <= 1'b0;
                        min_grade <= 8'd255;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current permutation
                    p0 <= perm_table[perm_counter*4 + 0];
                    p1 <= perm_table[perm_counter*4 + 1];
                    p2 <= perm_table[perm_counter*4 + 2];
                    p3 <= perm_table[perm_counter*4 + 3];
                    
                    // Get current operators
                    op1 <= op_counter[5:3];
                    op2 <= op_counter[2:0];
                    op3 <= op_counter[5:3];  // Simplified for example
                    
                    // Get current tree
                    current_tree <= tree_counter;
                    
                    // Evaluate expression based on tree
                    case (current_tree)
                        TREE1: begin  // ((a op b) op c) op d
                            // First operation (a op b)
                            if (op1 == ADD) temp1 <= a + b;
                            else if (op1 == SUB) temp1 <= a - b;
                            else if (op1 == MUL) temp1 <= a * b;
                            else if (op1 == DIV && b != 0 && a % b == 0) temp1 <= a / b;
                            else temp1 <= 16'd0;
                            
                            // Second operation ((a op b) op c)
                            if (op2 == ADD) temp2 <= temp1 + c;
                            else if (op2 == SUB) temp2 <= temp1 - c;
                            else if (op2 == MUL) temp2 <= temp1 * c;
                            else if (op2 == DIV && c != 0 && temp1 % c == 0) temp2 <= temp1 / c;
                            else temp2 <= 16'd0;
                            
                            // Third operation (((a op b) op c) op d)
                            if (op3 == ADD) result1 <= temp2 + d;
                            else if (op3 == SUB) result1 <= temp2 - d;
                            else if (op3 == MUL) result1 <= temp2 * d;
                            else if (op3 == DIV && d != 0 && temp2 % d == 0) result1 <= temp2 / d;
                            else result1 <= 16'd0;
                        end
                        
                        TREE2: begin  // (a op (b op c)) op d
                            // First operation (b op c)
                            if (op2 == ADD) temp3 <= b + c;
                            else if (op2 == SUB) temp3 <= b - c;
                            else if (op2 == MUL) temp3 <= b * c;
                            else if (op2 == DIV && c != 0 && b % c == 0) temp3 <= b / c;
                            else temp3 <= 16'd0;
                            
                            // Second operation (a op (b op c))
                            if (op1 == ADD) temp4 <= a + temp3;
                            else if (op1 == SUB) temp4 <= a - temp3;
                            else if (op1 == MUL) temp4 <= a * temp3;
                            else if (op1 == DIV && temp3 != 0 && a % temp3 == 0) temp4 <= a / temp3;
                            else temp4 <= 16'd0;
                            
                            // Third operation ((a op (b op c)) op d)
                            if (op3 == ADD) result2 <= temp4 + d;
                            else if (op3 == SUB) result2 <= temp4 - d;
                            else if (op3 == MUL) result2 <= temp4 * d;
                            else if (op3 == DIV && d != 0 && temp4 % d == 0) result2 <= temp4 / d;
                            else result2 <= 16'd0;
                        end
                        
                        TREE3: begin  // a op ((b op c) op d)
                            // First operation (c op d)
                            if (op3 == ADD) temp5 <= c + d;
                            else if (op3 == SUB) temp5 <= c - d;
                            else if (op3 == MUL) temp5 <= c * d;
                            else if (op3 == DIV && d != 0 && c % d == 0) temp5 <= c / d;
                            else temp5 <= 16'd0;
                            
                            // Second operation ((b op c) op d)
                            if (op2 == ADD) temp6 <= b + temp5;
                            else if (op2 == SUB) temp6 <= b - temp5;
                            else if (op2 == MUL) temp6 <= b * temp5;
                            else if (op2 == DIV && temp5 != 0 && b % temp5 == 0) temp6 <= b / temp5;
                            else temp6 <= 16'd0;
                            
                            // Third operation (a op ((b op c) op d))
                            if (op1 == ADD) result3 <= a + temp6;
                            else if (op1 == SUB) result3 <= a - temp6;
                            else if (op1 == MUL) result3 <= a * temp6;
                            else if (op1 == DIV && temp6 != 0 && a % temp6 == 0) result3 <= a / temp6;
                            else result3 <= 16'd0;
                        end
                        
                        TREE4: begin  // a op (b op (c op d))
                            // First operation (c op d)
                            if (op3 == ADD) temp7 <= c + d;
                            else if (op3 == SUB) temp7 <= c - d;
                            else if (op3 == MUL) temp7 <= c * d;
                            else if (op3 == DIV && d != 0 && c % d == 0) temp7 <= c / d;
                            else temp7 <= 16'd0;
                            
                            // Second operation (b op (c op d))
                            if (op2 == ADD) temp8 <= b + temp7;
                            else if (op2 == SUB) temp8 <= b - temp7;
                            else if (op2 == MUL) temp8 <= b * temp7;
                            else if (op2 == DIV && temp7 != 0 && b % temp7 == 0) temp8 <= b / temp7;
                            else temp8 <= 16'd0;
                            
                            // Third operation (a op (b op (c op d)))
                            if (op1 == ADD) result4 <= a + temp8;
                            else if (op1 == SUB) result4 <= a - temp8;
                            else if (op1 == MUL) result4 <= a * temp8;
                            else if (op1 == DIV && temp8 != 0 && a % temp8 == 0) result4 <= a / temp8;
                            else result4 <= 16'd0;
                        end
                        
                        TREE5: begin  // (a op b) op (c op d)
                            // First operation (a op b)
                            if (op1 == ADD) temp9 <= a + b;
                            else if (op1 == SUB) temp9 <= a - b;
                            else if (op1 == MUL) temp9 <= a * b;
                            else if (op1 == DIV && b != 0 && a % b == 0) temp9 <= a / b;
                            else temp9 <= 16'd0;
                            
                            // Second operation (c op d)
                            if (op3 == ADD) temp10 <= c + d;
                            else if (op3 == SUB) temp10 <= c - d;
                            else if (op3 == MUL) temp10 <= c * d;
                            else if (op3 == DIV && d != 0 && c % d == 0) temp10 <= c / d;
                            else temp10 <= 16'd0;
                            
                            // Third operation ((a op b) op (c op d))
                            if (op2 == ADD) result5 <= temp9 + temp10;
                            else if (op2 == SUB) result5 <= temp9 - temp10;
                            else if (op2 == MUL) result5 <= temp9 * temp10;
                            else if (op2 == DIV && temp10 != 0 && temp9 % temp10 == 0) result5 <= temp9 / temp10;
                            else result5 <= 16'd0;
                        end
                    endcase
                    
                    // Check if any result equals 24
                    if (result1 == 16'd24 || result2 == 16'd24 || result3 == 16'd24 || result4 == 16'd24 || result5 == 16'd24) begin
                        // Calculate grade (simplified for example)
                        current_grade <= 8'd10;  // Placeholder for actual grade calculation
                        
                        // Update minimum grade
                        if (!found || current_grade < min_grade) begin
                            min_grade <= current_grade;
                            found <= 1'b1;
                        end
                    end
                    
                    // Move to next combination
                    if (tree_counter == 4) begin
                        if (op_counter == 63) begin
                            if (perm_counter == 23) begin
                                state <= FINISH;
                            end else begin
                                perm_counter <= perm_counter + 5'd1;
                                op_counter <= 6'd0;
                                tree_counter <= 3'd0;
                            end
                        end else begin
                            op_counter <= op_counter + 6'd1;
                            tree_counter <= 3'd0;
                        end
                    end else begin
                        tree_counter <= tree_counter + 3'd1;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (found) begin
                        grade <= min_grade;
                    end else begin
                        grade <= 8'hFF;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule