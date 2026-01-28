module find_fragment #(
    parameter MAX_S_LEN = 16,
    parameter MAX_T_LEN = 16,
    parameter CHAR_WIDTH = 8,
    parameter PATTERNS_WIDTH = 4 * MAX_T_LEN
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [MAX_S_LEN*CHAR_WIDTH-1:0] S_flat,
    input wire [MAX_T_LEN*CHAR_WIDTH-1:0] T_flat,
    input wire [4:0] len_S,
    input wire [4:0] len_T,
    output reg done,
    output reg [4:0] count,
    output reg [CHAR_WIDTH-1:0] substring [0:MAX_T_LEN-1]
);
    // State encoding
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CLEAR_T        = 3'd1;
    localparam [2:0] COMPUTE_T      = 3'd2;
    localparam [2:0] CLEAR_S        = 3'd3;
    localparam [2:0] CALC_PATTERN   = 3'd4;
    localparam [2:0] COMPARE        = 3'd5;
    localparam [2:0] INCREMENT_I    = 3'd6;
    localparam [2:0] DONE_STATE     = 3'd7;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] i_reg;
    reg [4:0] j_reg;
    reg [4:0] max_i;
    reg [4:0] len_S_reg;
    reg [4:0] len_T_reg;
    reg [MAX_S_LEN*CHAR_WIDTH-1:0] S_reg;
    reg [MAX_T_LEN*CHAR_WIDTH-1:0] T_reg;
    reg [PATTERNS_WIDTH-1:0] pattern_T_reg;
    reg [PATTERNS_WIDTH-1:0] pattern_S_reg;
    reg [3:0] mapping [0:25];
    reg [0:25] seen;
    reg [7:0] cycle_counter;  // Prevent infinite loops
    
    // Internal variables
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            count <= 5'd0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            len_S_reg <= 5'd0;
            len_T_reg <= 5'd0;
            pattern_T_reg <= {PATTERNS_WIDTH{1'b0}};
            pattern_S_reg <= {PATTERNS_WIDTH{1'b0}};
            cycle_counter <= 8'd0;
            
            // Array initializations
            for (k = 0; k < 26; k = k+1) begin
                mapping[k] <= 4'd0;
                seen[k] <= 1'b0;
            end
            for (k = 0; k < MAX_T_LEN; k = k+1) begin
                substring[k] <= 8'd0;
            end
        end 
        else begin
            cycle_counter <= cycle_counter + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        S_reg <= S_flat;
                        T_reg <= T_flat;
                        len_S_reg <= len_S;
                        len_T_reg <= len_T;
                        count <= 5'd0;
                        i_reg <= 5'd0;
                        if (len_S < len_T) begin
                            state <= DONE_STATE;
                        end 
                        else begin
                            max_i <= len_S - len_T;
                            state <= CLEAR_T;
                        end
                        cycle_counter <= 8'd0;
                    end
                end
                
                CLEAR_T: begin
                    // Reset mapping and seen
                    for (k = 0; k < 26; k = k + 1) begin
                        seen[k] <= 1'b0;
                        mapping[k] <= 4'd0;
                    end
                    j_reg <= 5'd0;
                    state <= COMPUTE_T;
                end
                
                COMPUTE_T: begin
                    if (j_reg < len_T_reg) begin
                        if ($time > 10000) $finish;  // Simulation guard
                        
                        if (seen[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"]) begin
                            pattern_T_reg[j_reg*4 +: 4] <= mapping[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"];
                        end 
                        else begin
                            seen[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= 1'b1;
                            mapping[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= j_reg[3:0];
                            pattern_T_reg[j_reg*4 +: 4] <= j_reg[3:0];
                        end
                        j_reg <= j_reg + 5'd1;
                        if (cycle_counter > 8'd200) state <= DONE_STATE;
                    end
                    else begin
                        state <= CLEAR_S;
                    end
                end
                
                CLEAR_S: begin
                    for (k = 0; k < 26; k = k + 1) begin
                        seen[k] <= 1'b0;
                        mapping[k] <= 4'd0;
                    end
                    j_reg <= 5'd0;
                    state <= CALC_PATTERN;
                end
                
                CALC_PATTERN: begin
                    if (j_reg < len_T_reg) begin
                        if (seen[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"]) begin
                            pattern_S_reg[j_reg*4 +: 4] <= mapping[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"];
                        end 
                        else begin
                            seen[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= 1'b1;
                            mapping[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= j_reg[3:0];
                            pattern_S_reg[j_reg*4 +: 4] <= j_reg[3:0];
                        end
                        j_reg <= j_reg + 5'd1;
                        if (cycle_counter > 8'd200) state <= DONE_STATE;
                    end
                    else begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    if (pattern_T_reg == pattern_S_reg) begin
                        count <= count + 5'd1;
                        if (count == 5'd0) begin
                            // Capture first occurrence
                            for (k = 0; k < MAX_T_LEN; k = k+1) begin
                                if (k < len_T_reg) begin
                                    substring[k] <= S_reg[(i_reg + k)*CHAR_WIDTH +: CHAR_WIDTH];
                                end
                            end
                        end
                    end
                    state <= INCREMENT_I;
                end
                
                INCREMENT_I: begin
                    i_reg <= i_reg + 5'd1;
                    if (i_reg < max_i) begin
                        state <= CLEAR_S;
                    end
                    else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (!$test$plusargs("sim")) begin  // Avoid instant return in simulation
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule