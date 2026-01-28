module count_sequences(
    input clk,
    input rst_n,
    input start,
    input [3:0] m,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;
    localparam [2:0] RESET = 3'd4;
    
    // State registers
    reg [2:0] state, next_state;
    
    // Loop counters
    reg [3:0] i_reg;          // Row index (0 to m)
    reg [3:0] j_reg;          // Column index (0 to n)
    reg [3:0] i_next, j_next;
    
    // Table T[m+1][n+1] - using distributed RAM structure
    // 17x17 table, each entry 16 bits
    reg [15:0] table [0:16][0:16];
    reg [15:0] table_next [0:16][0:16];
    
    // Computation intermediate values
    reg [15:0] term1;         // T[i-1][j]
    reg [15:0] term2;         // T[i//2][j-1]
    reg [15:0] new_value;
    
    // Cycle counter for timeout protection
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Division by 2 (i//2)
    wire [3:0] i_div_2;
    assign i_div_2 = i_reg >> 1;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize table to zeros
            for (int r = 0; r < 17; r = r + 1) begin
                for (int c = 0; c < 17; c = c + 1) begin
                    table[r][c] <= 16'd0;
                end
            end
        end else begin
            // Update state
            state <= next_state;
            
            // Update counters and table
            i_reg <= i_next;
            j_reg <= j_next;
            cycle_count <= cycle_count + 8'd1;
            
            // Update table entries
            for (int r = 0; r < 17; r = r + 1) begin
                for (int c = 0; c < 17; c = c + 1) begin
                    table[r][c] <= table_next[r][c];
                end
            end
            
            // Update result in COMPLETE state
            if (state == COMPLETE) begin
                result <= table[m][n];
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
    
    // Next state and output logic (combinational)
    always @(*) begin
        // Default values
        next_state = state;
        i_next = i_reg;
        j_next = j_reg;
        
        // Default table: keep current values
        for (int r = 0; r < 17; r = r + 1) begin
            for (int c = 0; c < 17; c = c + 1) begin
                table_next[r][c] = table[r][c];
            end
        end
        
        // Default computation values
        term1 = 16'd0;
        term2 = 16'd0;
        new_value = 16'd0;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = INIT;
                    i_next = 4'd0;
                    j_next = 4'd0;
                    cycle_count = 8'd0;
                    // Reset table to zeros
                    for (int r = 0; r < 17; r = r + 1) begin
                        for (int c = 0; c < 17; c = c + 1) begin
                            table_next[r][c] = 16'd0;
                        end
                    end
                end
            end
            
            INIT: begin
                // Initialize table entries to 0 (already done in IDLE)
                // Move to compute
                next_state = COMPUTE;
                i_next = 4'd1;
                j_next = 4'd1;
            end
            
            COMPUTE: begin
                // Boundary condition: if i < j, T[i][j] = 0
                if (i_reg < j_reg) begin
                    table_next[i_reg][j_reg] = 16'd0;
                end
                // T[i][1] = i for i >= 1
                else if (j_reg == 4'd1) begin
                    table_next[i_reg][j_reg] = {12'd0, i_reg};
                end
                // T[i][j] = T[i-1][j] + T[i//2][j-1] for j >= 2
                else begin
                    term1 = table[i_reg - 4'd1][j_reg];
                    term2 = table[i_div_2][j_reg - 4'd1];
                    new_value = term1 + term2;
                    table_next[i_reg][j_reg] = new_value;
                end
                
                // Update counters
                if (j_reg < n) begin
                    j_next = j_reg + 4'd1;
                end else begin
                    j_next = 4'd1;
                    if (i_reg < m) begin
                        i_next = i_reg + 4'd1;
                    end else begin
                        // Computation complete
                        next_state = COMPLETE;
                    end
                end
                
                // Timeout protection
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                // Result is assigned in sequential block
                next_state = IDLE;
                i_next = 4'd0;
                j_next = 4'd0;
                cycle_count = 8'd0;
            end
            
            default: begin
                next_state = IDLE;
                i_next = 4'd0;
                j_next = 4'd0;
            end
        endcase
    end
endmodule