module bell_numbers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [63:0] result,
    output reg done
);

// State declarations
localparam [2:0] IDLE    = 3'd0;
localparam [2:0] INIT    = 3'd1;
localparam [2:0] LOOP_I  = 3'd2;
localparam [2:0] LOOP_J  = 3'd3;
localparam [2:0] UPDATE  = 3'd4;
localparam [2:0] FINISH  = 3'd5;

// Internal registers
reg [2:0] state;
reg [3:0] i_reg, j_reg;
reg [63:0] bell [0:8][0:8];
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

// Combinational next state logic
reg [2:0] next_state;
reg [3:0] next_i, next_j;
reg [63:0] next_result;
reg next_done;
reg [7:0] next_cycle_count;

// Combinational signals for array update
reg [63:0] bell_next [0:8][0:8];
integer row_idx, col_idx;

always @(*) begin
    // Default assignments
    next_state = state;
    next_i = i_reg;
    next_j = j_reg;
    next_result = result;
    next_done = done;
    next_cycle_count = cycle_count + 8'd1;
    
    // Copy bell to bell_next
    for (row_idx = 0; row_idx < 9; row_idx = row_idx + 1) begin
        for (col_idx = 0; col_idx < 9; col_idx = col_idx + 1) begin
            bell_next[row_idx][col_idx] = bell[row_idx][col_idx];
        end
    end
    
    case (state)
        IDLE: begin
            next_done = 1'b0;
            next_cycle_count = 8'd0;
            if (start) begin
                next_state = INIT;
            end
        end
        
        INIT: begin
            bell_next[0][0] = 64'd1;
            next_i = 4'd1;
            next_j = 4'd0;
            next_state = LOOP_I;
        end
        
        LOOP_I: begin
            if (i_reg <= n) begin
                bell_next[i_reg][0] = bell[i_reg-1][i_reg-1];
                next_j = 4'd1;
                next_state = LOOP_J;
            end else begin
                next_state = FINISH;
            end
        end
        
        LOOP_J: begin
            if (j_reg <= i_reg) begin
                next_state = UPDATE;
            end else begin
                next_i = i_reg + 4'd1;
                next_j = 4'd0;
                next_state = LOOP_I;
            end
        end
        
        UPDATE: begin
            bell_next[i_reg][j_reg] = bell[i_reg-1][j_reg-1] + bell[i_reg][j_reg-1];
            next_j = j_reg + 4'd1;
            next_state = LOOP_J;
        end
        
        FINISH: begin
            next_result = bell[n][0];
            next_done = 1'b1;
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
    
    // Prevent infinite loops
    if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
        next_state = IDLE;
        next_done = 1'b1;
    end
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i_reg <= 4'd0;
        j_reg <= 4'd0;
        result <= 64'd0;
        done <= 1'b0;
        cycle_count <= 8'd0;
        // Initialize bell array
        for (row_idx = 0; row_idx < 9; row_idx = row_idx + 1) begin
            for (col_idx = 0; col_idx < 9; col_idx = col_idx + 1) begin
                bell[row_idx][col_idx] <= 64'd0;
            end
        end
    end else begin
        state <= next_state;
        i_reg <= next_i;
        j_reg <= next_j;
        result <= next_result;
        done <= next_done;
        cycle_count <= next_cycle_count;
        // Update bell array
        for (row_idx = 0; row_idx < 9; row_idx = row_idx + 1) begin
            for (col_idx = 0; col_idx < 9; col_idx = col_idx + 1) begin
                bell[row_idx][col_idx] <= bell_next[row_idx][col_idx];
            end
        end
    end
end

endmodule