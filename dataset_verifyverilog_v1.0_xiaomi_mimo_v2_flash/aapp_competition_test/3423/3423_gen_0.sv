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

localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE = 3'd1;
localparam [2:0] DONE = 3'd2;

reg [2:0] state, next_state;
reg [MAX_PACKAGES-1:0] indegree [0:7];
reg [MAX_PACKAGES-1:0] installed;
reg [3:0] install_cnt;
reg [3:0] cycle_cnt;
reg [NAME_WIDTH-1:0] best_name;
reg [3:0] best_idx;

integer i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_len <= 4'd0;
        done <= 1'b0;
        error <= 1'b0;
        install_cnt <= 4'd0;
        cycle_cnt <= 4'd0;
        installed <= 8'd0;
        for (i = 0; i < 8; i = i + 1) begin
            indegree[i] <= 8'd0;
        end
        result_0 <= 128'd0;
        result_1 <= 128'd0;
        result_2 <= 128'd0;
        result_3 <= 128'd0;
        result_4 <= 128'd0;
        result_5 <= 128'd0;
        result_6 <= 128'd0;
        result_7 <= 128'd0;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = COMPUTE;
        COMPUTE: if (error || (install_cnt == num_packages) || (cycle_cnt >= 4'd100)) next_state = DONE;
        DONE: if (!start) next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_len <= 4'd0;
        done <= 1'b0;
        error <= 1'b0;
        install_cnt <= 4'd0;
        cycle_cnt <= 4'd0;
        installed <= 8'd0;
        best_idx <= 4'd8;
        best_name <= 128'd0;
        for (i = 0; i < 8; i = i + 1) begin
            indegree[i] <= 8'd0;
        end
        result_0 <= 128'd0;
        result_1 <= 128'd0;
        result_2 <= 128'd0;
        result_3 <= 128'd0;
        result_4 <= 128'd0;
        result_5 <= 128'd0;
        result_6 <= 128'd0;
        result_7 <= 128'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                error <= 1'b0;
                install_cnt <= 4'd0;
                cycle_cnt <= 4'd0;
                installed <= 8'd0;
                result_len <= 4'd0;
                best_idx <= 4'd8;
                best_name <= 128'd0;
                for (i = 0; i < 8; i = i + 1) begin
                    indegree[i] <= 8'd0;
                end
                result_0 <= 128'd0;
                result_1 <= 128'd0;
                result_2 <= 128'd0;
                result_3 <= 128'd0;
                result_4 <= 128'd0;
                result_5 <= 128'd0;
                result_6 <= 128'd0;
                result_7 <= 128'd0;
            end
            COMPUTE: begin
                cycle_cnt <= cycle_cnt + 4'd1;
                if (install_cnt == 4'd0) begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < num_packages) begin
                            indegree[i] <= 8'd0;
                            if (deps_0[i]) indegree[i] <= indegree[i] + 8'd1;
                            if (deps_1[i]) indegree[i] <= indegree[i] + 8'd1;
                            if (deps_2[i]) indegree[i] <= indegree[i] + 8'd1;
                            if (deps_3[i]) indegree[i] <= indegree[i] + 8'd1;
                            if (deps_4[i]) indegree[i] <= indegree[i] + 8'd1;
                            if (deps_5[i]) indegree[i] <= indegree[i] + 8'd1;
                            if (deps_6[i]) indegree[i] <= indegree[i] + 8'd1;
                            if (deps_7[i]) indegree[i] <= indegree[i] + 8'd1;
                        end
                    end
                end else begin
                    best_idx <= 4'd8;
                    best_name <= 128'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < num_packages && !installed[i] && indegree[i] == 8'd0) begin
                            if (i == 0) begin
                                if (best_idx == 4'd8 || pkg_0 < best_name) begin
                                    best_idx <= 4'd0;
                                    best_name <= pkg_0;
                                end
                            end else if (i == 1) begin
                                if (best_idx == 4'd8 || pkg_1 < best_name) begin
                                    best_idx <= 4'd1;
                                    best_name <= pkg_1;
                                end
                            end else if (i == 2) begin
                                if (best_idx == 4'd8 || pkg_2 < best_name) begin
                                    best_idx <= 4'd2;
                                    best_name <= pkg_2;
                                end
                            end else if (i == 3) begin
                                if (best_idx == 4'd8 || pkg_3 < best_name) begin
                                    best_idx <= 4'd3;
                                    best_name <= pkg_3;
                                end
                            end else if (i == 4) begin
                                if (best_idx == 4'd8 || pkg_4 < best_name) begin
                                    best_idx <= 4'd4;
                                    best_name <= pkg_4;
                                end
                            end else if (i == 5) begin
                                if (best_idx == 4'd8 || pkg_5 < best_name) begin
                                    best_idx <= 4'd5;
                                    best_name <= pkg_5;
                                end
                            end else if (i == 6) begin
                                if (best_idx == 4'd8 || pkg_6 < best_name) begin
                                    best_idx <= 4'd6;
                                    best_name <= pkg_6;
                                end
                            end else if (i == 7) begin
                                if (best_idx == 4'd8 || pkg_7 < best_name) begin
                                    best_idx <= 4'd7;
                                    best_name <= pkg_7;
                                end
                            end
                        end
                    end
                    if (best_idx < 4'd8) begin
                        installed[best_idx] <= 1'b1;
                        install_cnt <= install_cnt + 4'd1;
                        if (install_cnt == 4'd0) begin
                            result_0 <= best_name;
                        end else if (install_cnt == 4'd1) begin
                            result_1 <= best_name;
                        end else if (install_cnt == 4'd2) begin
                            result_2 <= best_name;
                        end else if (install_cnt == 4'd3) begin
                            result_3 <= best_name;
                        end else if (install_cnt == 4'd4) begin
                            result_4 <= best_name;
                        end else if (install_cnt == 4'd5) begin
                            result_5 <= best_name;
                        end else if (install_cnt == 4'd6) begin
                            result_6 <= best_name;
                        end else if (install_cnt == 4'd7) begin
                            result_7 <= best_name;
                        end
                        result_len <= install_cnt + 4'd1;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (j < num_packages && !installed[j]) begin
                                if (best_idx == 4'd0 && deps_0[j]) indegree[j] <= indegree[j] - 8'd1;
                                if (best_idx == 4'd1 && deps_1[j]) indegree[j] <= indegree[j] - 8'd1;
                                if (best_idx == 4'd2 && deps_2[j]) indegree[j] <= indegree[j] - 8'd1;
                                if (best_idx == 4'd3 && deps_3[j]) indegree[j] <= indegree[j] - 8'd1;
                                if (best_idx == 4'd4 && deps_4[j]) indegree[j] <= indegree[j] - 8'd1;
                                if (best_idx == 4'd5 && deps_5[j]) indegree[j] <= indegree[j] - 8'd1;
                                if (best_idx == 4'd6 && deps_6[j]) indegree[j] <= indegree[j] - 8'd1;
                                if (best_idx == 4'd7 && deps_7[j]) indegree[j] <= indegree[j] - 8'd1;
                            end
                        end
                    end else if (install_cnt < num_packages) begin
                        error <= 1'b1;
                    end
                end
            end
            DONE: begin
                done <= 1'b1;
            end
            default: begin
                result_len <= 4'd0;
                done <= 1'b0;
                error <= 1'b0;
                install_cnt <= 4'd0;
                cycle_cnt <= 4'd0;
                installed <= 8'd0;
                best_idx <= 4'd8;
                best_name <= 128'd0;
                for (i = 0; i < 8; i = i + 1) begin
                    indegree[i] <= 8'd0;
                end
                result_0 <= 128'd0;
                result_1 <= 128'd0;
                result_2 <= 128'd0;
                result_3 <= 128'd0;
                result_4 <= 128'd0;
                result_5 <= 128'd0;
                result_6 <= 128'd0;
                result_7 <= 128'd0;
            end
        endcase
    end
end

endmodule