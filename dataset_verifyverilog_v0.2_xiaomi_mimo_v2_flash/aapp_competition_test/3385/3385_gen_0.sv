module costume_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] i,
    input wire [3:0] l,
    input wire [3:0] r,
    input wire x,
    output reg [29:0] result,
    output reg done,
    output reg impossible
);

    // Constants
    localparam MOD = 30'b111011100110101100101000000111; // 1000000007
    
    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam SOLVE = 3'b010;
    localparam CALC = 3'b011;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [3:0] n_reg;
    reg [3:0] rank;
    
    // Matrix storage: 16 rows, 17 columns
    reg [16:0] matrix [0:15];
    
    // Counters and temps
    reg [3:0] row_cnt;   // Loading counter and loop index
    reg [3:0] col_cnt;   // Pivot column
    reg [3:0] search_cnt; // Pivot search row
    reg [3:0] elim_cnt;   // Elimination row
    reg [16:0] temp_row;  // For swapping
    
    // Power calc registers
    reg [29:0] pow_res;
    reg [3:0] pow_cnt;
    
    // Combinational Logic
    // 1. Loaded Row Calculation
    reg [16:0] loaded_row;
    integer k;
    always @(*) begin
        loaded_row = 0;
        // Calculate start index: (i - l) mod n
        reg [3:0] start;
        if (i >= l) start = i - l;
        else start = i - l + n_reg;
        
        // Calculate length: l + r + 1
        reg [4:0] len;
        len = l + r + 1;
        
        // Set bits for indices in window
        for (k = 0; k < 16; k = k + 1) begin
            if (k < n_reg) begin
                reg [4:0] dist;
                if (k >= start) dist = k - start;
                else dist = k - start + n_reg;
                
                if (dist < len) loaded_row[k] = 1;
            end
        end
        loaded_row[16] = x;
    end
    
    // 2. Inconsistency Check
    wire is_inconsistent;
    reg [16:0] mask;
    integer r;
    assign is_inconsistent = (mask == 0) ? 1'b0 : 1'b0; // Dummy to force usage
    
    reg inconsistency_flag;
    always @(*) begin
        inconsistency_flag = 0;
        mask = 0;
        for (int m = 0; m < 16; m++) begin
            if (m < n_reg) mask[m] = 1;
        end
        for (r = 0; r < 16; r = r + 1) begin
            if (r < n_reg) begin
                if ((matrix[r] & mask) == 0 && matrix[r][16]) begin
                    inconsistency_flag = 1;
                end
            end
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            impossible <= 0;
            result <= 0;
            row_cnt <= 0;
            col_cnt <= 0;
            rank <= 0;
            pow_res <= 0;
            pow_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    result <= 0;
                    if (start) begin
                        n_reg <= n;
                        row_cnt <= 0;
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Update matrix[i] with calculated row
                    matrix[i] <= loaded_row;
                    row_cnt <= row_cnt + 1;
                    
                    if (row_cnt + 1 == n_reg) begin
                        state <= SOLVE;
                        col_cnt <= 0;
                        search_cnt <= 0;
                        elim_cnt <= 0;
                        rank <= 0;
                    end
                end
                
                SOLVE: begin
                    // Elimination phase (rows 0 to n-1)
                    if (elim_cnt < n_reg) begin
                        if (elim_cnt != col_cnt && matrix[elim_cnt][col_cnt]) begin
                            matrix[elim_cnt] <= matrix[elim_cnt] ^ matrix[col_cnt];
                        end
                        elim_cnt <= elim_cnt + 1;
                    end 
                    else begin
                        // Pivot phase
                        if (search_cnt < n_reg) begin
                            if (matrix[search_cnt][col_cnt]) begin
                                // Pivot found
                                if (search_cnt != col_cnt) begin
                                    temp_row <= matrix[col_cnt];
                                    matrix[col_cnt] <= matrix[search_cnt];
                                    matrix[search_cnt] <= temp_row;
                                end
                                rank <= rank + 1;
                                elim_cnt <= 0; // Restart elimination for next step
                            end else begin
                                search_cnt <= search_cnt + 1;
                            end
                        end else begin
                            // No pivot in this column
                            col_cnt <= col_cnt + 1;
                            search_cnt <= col_cnt + 1;
                            if (col_cnt + 1 == n_reg) begin
                                state <= CALC;
                                row_cnt <= 0;
                                pow_res <= 1;
                                pow_cnt <= 0;
                            end
                        end
                    end
                end
                
                CALC: begin
                    if (row_cnt == 0) begin
                        // Check inconsistency
                        if (inconsistency_flag) begin
                            impossible <= 1;
                            result <= 0;
                            done <= 1;
                            state <= DONE;
                        end else begin
                            row_cnt <= 1;
                            // Check if rank == n (result = 1)
                            if (rank == n_reg) begin
                                result <= 1;
                                done <= 1;
                                state <= DONE;
                            end else begin
                                pow_res <= 1;
                                pow_cnt <= 0;
                            end
                        end
                    end else begin
                        // Power calculation: 2^(n-rank) mod MOD
                        if (pow_cnt < (n_reg - rank)) begin
                            // Multiply by 2 modulo MOD
                            if (pow_res >= (MOD >> 1)) begin
                                pow_res <= (pow_res << 1) - MOD;
                            end else begin
                                pow_res <= (pow_res << 1);
                            end
                            pow_cnt <= pow_cnt + 1;
                        end else begin
                            result <= pow_res;
                            done <= 1;
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule