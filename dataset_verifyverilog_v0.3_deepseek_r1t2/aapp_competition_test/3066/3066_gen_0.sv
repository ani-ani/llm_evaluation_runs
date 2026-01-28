module tape_art_solver #(
    parameter MAX_N = 16,
    parameter MAX_COLOR = 16,
    parameter DATA_WIDTH = 4,
    parameter ADDR_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [ADDR_WIDTH-1:0] n,
    input wire [DATA_WIDTH-1:0] colors [0:MAX_N-1],
    
    output reg done,
    output reg impossible,
    output reg [ADDR_WIDTH-1:0] num_instructions,
    output reg [ADDR_WIDTH-1:0] inst_l [0:MAX_COLOR-1],
    output reg [ADDR_WIDTH-1:0] inst_r [0:MAX_COLOR-1],
    output reg [DATA_WIDTH-1:0] inst_c [0:MAX_COLOR-1],
    output reg inst_valid [0:MAX_COLOR-1]
);
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_SCAN = 3'd1;
    localparam [2:0] S_CHECK = 3'd2;
    localparam [2:0] S_SORT = 3'd3;
    localparam [2:0] S_OUTPUT = 3'd4;
    localparam [2:0] S_DONE = 3'd5;
    localparam [2:0] S_IMPOSSIBLE = 3'd6;
    
    reg [2:0] state, next_state;
    reg [ADDR_WIDTH-1:0] L [0:MAX_COLOR-1];
    reg [ADDR_WIDTH-1:0] R [0:MAX_COLOR-1];
    reg present [0:MAX_COLOR-1];
    reg [ADDR_WIDTH-1:0] idx, i, j, sort_i, sort_j, min_idx;
    reg [ADDR_WIDTH-1:0] temp_L, temp_R;
    reg [DATA_WIDTH-1:0] temp_C;
    reg temp_valid;
    
    always @(posedge clk or negedge rst_n)
        if (!rst_n) state <= S_IDLE;
        else state <= next_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            impossible <= 1'b0;
            num_instructions <= {ADDR_WIDTH{1'b0}};
            idx <= {ADDR_WIDTH{1'b0}};
            i <= {ADDR_WIDTH{1'b0}};
            j <= {ADDR_WIDTH{1'b0}};
            sort_i <= {ADDR_WIDTH{1'b0}};
            sort_j <= {ADDR_WIDTH{1'b0}};
            min_idx <= {ADDR_WIDTH{1'b0}};
            temp_L <= {ADDR_WIDTH{1'b0}};
            temp_R <= {ADDR_WIDTH{1'b0}};
            temp_C <= {DATA_WIDTH{1'b0}};
            temp_valid <= 1'b0;
            
            for (integer k = 0; k < MAX_COLOR; k = k + 1) begin
                L[k] <= {ADDR_WIDTH{1'b0}};
                R[k] <= {ADDR_WIDTH{1'b0}};
                present[k] <= 1'b0;
                inst_l[k] <= {ADDR_WIDTH{1'b0}};
                inst_r[k] <= {ADDR_WIDTH{1'b0}};
                inst_c[k] <= {DATA_WIDTH{1'b0}};
                inst_valid[k] <= 1'b0;
            end
            next_state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        idx <= {ADDR_WIDTH{1'b0}};
                        for (integer k = 0; k < MAX_COLOR; k = k + 1) begin
                            L[k] <= {ADDR_WIDTH{1'b0}};
                            R[k] <= {ADDR_WIDTH{1'b0}};
                            present[k] <= 1'b0;
                        end
                        next_state <= S_SCAN;
                    end else begin
                        next_state <= S_IDLE;
                    end
                end
                
                S_SCAN: begin
                    if (idx < n) begin
                        if (present[colors[idx]] == 1'b0) begin
                            present[colors[idx]] <= 1'b1;
                            L[colors[idx]] <= idx;
                            R[colors[idx]] <= idx;
                        end else begin
                            R[colors[idx]] <= idx;
                        end
                        idx <= idx + 1;
                        next_state <= S_SCAN;
                    end else begin
                        i <= {ADDR_WIDTH{1'b0}};
                        j <= {ADDR_WIDTH{1'b0}} + 1;
                        next_state <= S_CHECK;
                    end
                end
                
                S_CHECK: begin
                    if (i >= MAX_COLOR) begin
                        sort_i <= {ADDR_WIDTH{1'b0}};
                        sort_j <= {ADDR_WIDTH{1'b0}} + 1;
                        min_idx <= {ADDR_WIDTH{1'b0}};
                        next_state <= S_SORT;
                    end else if (j >= MAX_COLOR) begin
                        i <= i + 1;
                        j <= i + 2;
                    end else if (present[i] && present[j]) begin
                        if ((R[i] >= L[j] && L[i] <= R[j]) && 
                            !((L[i] <= L[j] && R[j] <= R[i]) || 
                              (L[j] <= L[i] && R[i] <= R[j]))) begin
                            impossible <= 1'b1;
                            next_state <= S_IMPOSSIBLE;
                        end else begin
                            j <= j + 1;
                        end
                    end else begin
                        j <= j + 1;
                    end
                end
                
                S_SORT: begin
                    if (sort_i >= MAX_COLOR - 1) begin
                        i <= {ADDR_WIDTH{1'b0}};
                        num_instructions <= {ADDR_WIDTH{1'b0}};
                        next_state <= S_OUTPUT;
                    end else if (sort_j >= MAX_COLOR) begin
                        if (min_idx != sort_i) begin
                            temp_L <= L[sort_i];
                            L[sort_i] <= L[min_idx];
                            L[min_idx] <= temp_L;
                            
                            temp_R <= R[sort_i];
                            R[sort_i] <= R[min_idx];
                            R[min_idx] <= temp_R;
                            
                            temp_valid <= present[sort_i];
                            present[sort_i] <= present[min_idx];
                            present[min_idx] <= temp_valid;
                        end
                        sort_i <= sort_i + 1;
                        sort_j <= sort_i + 1;
                        min_idx <= sort_i + 1;
                    end else begin
                        if (present[sort_j]) begin
                            if ((sort_j > sort_i) && 
                                ((R[sort_j] - L[sort_j]) > (R[min_idx] - L[min_idx]))) begin
                                min_idx <= sort_j;
                            end
                        end
                        sort_j <= sort_j + 1;
                    end
                end
                
                S_OUTPUT: begin
                    if (i < MAX_COLOR) begin
                        inst_valid[i] <= present[i];
                        if (present[i]) begin
                            inst_l[i] <= L[i];
                            inst_r[i] <= R[i];
                            inst_c[i] <= i[DATA_WIDTH-1:0];
                            num_instructions <= num_instructions + 1;
                        end
                        i <= i + 1;
                    end else begin
                        done <= 1'b1;
                        next_state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    next_state <= S_DONE;
                end
                
                S_IMPOSSIBLE: begin
                    done <= 1'b1;
                    next_state <= S_IMPOSSIBLE;
                end
                
                default: begin
                    next_state <= S_IDLE;
                end
            endcase
        end
    end
endmodule