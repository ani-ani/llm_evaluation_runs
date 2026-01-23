module package_installer #(
    parameter MAX_PACKAGES = 8,
    parameter NAME_WIDTH = 128
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_packages,
    
    input [NAME_WIDTH-1:0] pkg_0,
    input [NAME_WIDTH-1:0] pkg_1,
    input [NAME_WIDTH-1:0] pkg_2,
    input [NAME_WIDTH-1:0] pkg_3,
    input [NAME_WIDTH-1:0] pkg_4,
    input [NAME_WIDTH-1:0] pkg_5,
    input [NAME_WIDTH-1:0] pkg_6,
    input [NAME_WIDTH-1:0] pkg_7,
    
    input [MAX_PACKAGES-1:0] deps_0,
    input [MAX_PACKAGES-1:0] deps_1,
    input [MAX_PACKAGES-1:0] deps_2,
    input [MAX_PACKAGES-1:0] deps_3,
    input [MAX_PACKAGES-1:0] deps_4,
    input [MAX_PACKAGES-1:0] deps_5,
    input [MAX_PACKAGES-1:0] deps_6,
    input [MAX_PACKAGES-1:0] deps_7,
    
    output reg [NAME_WIDTH-1:0] result_0,
    output reg [NAME_WIDTH-1:0] result_1,
    output reg [NAME_WIDTH-1:0] result_2,
    output reg [NAME_WIDTH-1:0] result_3,
    output reg [NAME_WIDTH-1:0] result_4,
    output reg [NAME_WIDTH-1:0] result_5,
    output reg [NAME_WIDTH-1:0] result_6,
    output reg [NAME_WIDTH-1:0] result_7,
    output reg [3:0] result_len,
    output reg done,
    output reg error
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] DONE_ST = 3'd2;
    
    reg [2:0] state, next_state;
    reg [MAX_PACKAGES-1:0] indegree [0:MAX_PACKAGES-1];
    reg [MAX_PACKAGES-1:0] installed;
    reg [3:0] install_cnt;
    reg [3:0] cycle_cnt;
    reg [NAME_WIDTH-1:0] best_name;
    reg [3:0] best_idx;
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            result_len <= 4'd0;
            install_cnt <= 4'd0;
            cycle_cnt <= 4'd0;
            installed <= {MAX_PACKAGES{1'b0}};
            
            for (i = 0; i < MAX_PACKAGES; i = i + 1)
                indegree[i] <= {MAX_PACKAGES{1'b0}};
            
            result_0 <= {NAME_WIDTH{1'b0}};
            result_1 <= {NAME_WIDTH{1'b0}};
            result_2 <= {NAME_WIDTH{1'b0}};
            result_3 <= {NAME_WIDTH{1'b0}};
            result_4 <= {NAME_WIDTH{1'b0}};
            result_5 <= {NAME_WIDTH{1'b0}};
            result_6 <= {NAME_WIDTH{1'b0}};
            result_7 <= {NAME_WIDTH{1'b0}};
        end
        else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    install_cnt <= 4'd0;
                    cycle_cnt <= 4'd0;
                    installed <= {MAX_PACKAGES{1'b0}};
                    
                    if (start) begin
                        // Initialize indegree arrays
                        for (i = 0; i < MAX_PACKAGES; i = i + 1) begin
                            if (i < num_packages) begin
                                indegree[i] <= deps_0[i] + deps_1[i] + deps_2[i] + 
                                             deps_3[i] + deps_4[i] + deps_5[i] + 
                                             deps_6[i] + deps_7[i];
                            end
                            else begin
                                indegree[i] <= {MAX_PACKAGES{1'b0}};
                            end
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_cnt <= cycle_cnt + 4'd1;
                    
                    // Find minimal package with in-degree 0
                    best_idx <= MAX_PACKAGES;
                    best_name <= {NAME_WIDTH{1'b1}};
                    
                    for (i = 0; i < MAX_PACKAGES; i = i + 1) begin
                        if (i < num_packages && !installed[i] && indegree[i] == 0) begin
                            case (i)
                                0: if (pkg_0 < best_name) begin best_name <= pkg_0; best_idx <= i; end
                                1: if (pkg_1 < best_name) begin best_name <= pkg_1; best_idx <= i; end
                                2: if (pkg_2 < best_name) begin best_name <= pkg_2; best_idx <= i; end
                                3: if (pkg_3 < best_name) begin best_name <= pkg_3; best_idx <= i; end
                                4: if (pkg_4 < best_name) begin best_name <= pkg_4; best_idx <= i; end
                                5: if (pkg_5 < best_name) begin best_name <= pkg_5; best_idx <= i; end
                                6: if (pkg_6 < best_name) begin best_name <= pkg_6; best_idx <= i; end
                                7: if (pkg_7 < best_name) begin best_name <= pkg_7; best_idx <= i; end
                            endcase
                        end
                    end
                    
                    if (best_idx < MAX_PACKAGES) begin
                        installed[best_idx] <= 1'b1;
                        install_cnt <= install_cnt + 4'd1;
                        case (install_cnt)
                            4'd0: result_0 <= best_name;
                            4'd1: result_1 <= best_name;
                            4'd2: result_2 <= best_name;
                            4'd3: result_3 <= best_name;
                            4'd4: result_4 <= best_name;
                            4'd5: result_5 <= best_name;
                            4'd6: result_6 <= best_name;
                            4'd7: result_7 <= best_name;
                        endcase
                        result_len <= install_cnt + 4'd1;
                        
                        // Update dependencies
                        for (j = 0; j < MAX_PACKAGES; j = j + 1) begin
                            if (j < num_packages && !installed[j]) begin
                                case (best_idx)
                                    0: if (deps_0[j]) indegree[j] <= indegree[j] - 1;
                                    1: if (deps_1[j]) indegree[j] <= indegree[j] - 1;
                                    2: if (deps_2[j]) indegree[j] <= indegree[j] - 1;
                                    3: if (deps_3[j]) indegree[j] <= indegree[j] - 1;
                                    4: if (deps_4[j]) indegree[j] <= indegree[j] - 1;
                                    5: if (deps_5[j]) indegree[j] <= indegree[j] - 1;
                                    6: if (deps_6[j]) indegree[j] <= indegree[j] - 1;
                                    7: if (deps_7[j]) indegree[j] <= indegree[j] - 1;
                                endcase
                            end
                        end
                    end
                    else if (install_cnt < num_packages) begin
                        error <= 1'b1;
                    end
                end
                
                DONE_ST: done <= 1'b1;
            endcase
        end
    end
    
    always @(*) begin
        case (state)
            IDLE:    next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = ((install_cnt == num_packages) || (cycle_cnt >= 8'd99) || error) ? DONE_ST : COMPUTE;
            DONE_ST: next_state = (done && !start) ? IDLE : DONE_ST;
            default: next_state = IDLE;
        endcase
    end
    
endmodule