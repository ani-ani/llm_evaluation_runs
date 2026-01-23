module package_manager (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] pkg_idx,
    input wire [79:0] pkg_name,
    input wire [79:0] dep_name,
    input wire dep_valid,
    input wire def_done,
    input wire [3:0] n_pkgs,
    output reg [79:0] result_name,
    output reg result_valid,
    output reg done,
    output reg error
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CONFIG = 3'b001;
    localparam SETUP_DEPS = 3'b010;
    localparam SEARCH = 3'b011;
    localparam OUTPUT = 3'b100;
    localparam UPDATE = 3'b101;
    localparam FINISHED = 3'b110;
    localparam ERROR_STATE = 3'b111;

    reg [2:0] state;

    // Storage
    reg [79:0] names [0:7];
    reg [7:0] valid_pkg;
    reg [2:0] deps [0:7][0:7];
    reg [2:0] dep_counts [0:7];

    // Runtime Data
    reg signed [2:0] indegree [0:7];
    reg [7:0] installed;
    reg [2:0] install_cnt;

    // Helper Registers
    reg [2:0] ptr;
    reg [2:0] search_ptr;
    reg [2:0] best_idx;
    reg [79:0] best_name;

    // Combinational: Name Lookup
    reg [2:0] lookup_res_idx;
    reg lookup_found;
    always @(*) begin
        lookup_found = 0;
        lookup_res_idx = 0;
        if (dep_valid) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                if (valid_pkg[i] && names[i] == dep_name) begin
                    lookup_found = 1;
                    lookup_res_idx = i[2:0];
                end
            end
        end
    end

    // Combinational: Lexicographical Compare
    reg is_smaller;
    always @(*) begin
        is_smaller = 0;
        if (valid_pkg[search_ptr]) begin
            for (integer b = 0; b < 10; b = b + 1) begin
                if (names[search_ptr][79-(8*b) : 72-(8*b)] != best_name[79-(8*b) : 72-(8*b)]) begin
                    if (names[search_ptr][79-(8*b) : 72-(8*b)] < best_name[79-(8*b) : 72-(8*b)]) begin
                        is_smaller = 1;
                    end
                    break;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_pkg <= 8'd0;
            install_cnt <= 0;
            installed <= 0;
            result_valid <= 0;
            done <= 0;
            error <= 0;
            ptr <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CONFIG;
                        valid_pkg <= 8'd0;
                        ptr <= 0;
                    end
                end

                CONFIG: begin
                    if (start) begin
                        state <= IDLE;
                    end else if (def_done) begin
                        if (!valid_pkg[pkg_idx]) begin
                            names[pkg_idx] <= pkg_name;
                            valid_pkg[pkg_idx] <= 1'b1;
                        end
                        ptr <= ptr + 1;
                        if (ptr + 1 == n_pkgs) begin
                            state <= SETUP_DEPS;
                            ptr <= 0;
                        end
                    end else if (dep_valid) begin
                        if (lookup_found && dep_counts[pkg_idx] < 8) begin
                            deps[pkg_idx][dep_counts[pkg_idx]] <= lookup_res_idx;
                            dep_counts[pkg_idx] <= dep_counts[pkg_idx] + 1;
                        end
                    end
                end

                SETUP_DEPS: begin
                    if (ptr < n_pkgs) begin
                        if (valid_pkg[ptr]) begin
                            indegree[ptr] <= dep_counts[ptr];
                        end
                        ptr <= ptr + 1;
                    end else begin
                        ptr <= 0;
                        search_ptr <= 0;
                        best_idx <= 3'b111;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (search_ptr < n_pkgs) begin
                        if (valid_pkg[search_ptr] && !installed[search_ptr] && indegree[search_ptr] == 0) begin
                            if (best_idx == 3'b111) begin
                                best_idx <= search_ptr;
                                best_name <= names[search_ptr];
                            end else if (is_smaller) begin
                                best_idx <= search_ptr;
                                best_name <= names[search_ptr];
                            end
                        end
                        search_ptr <= search_ptr + 1;
                    end else begin
                        search_ptr <= 0;
                        if (best_idx != 3'b111) begin
                            state <= OUTPUT;
                        end else begin
                            if (install_cnt < n_pkgs) state <= ERROR_STATE;
                            else state <= FINISHED;
                        end
                    end
                end

                OUTPUT: begin
                    result_name <= names[best_idx];
                    result_valid <= 1'b1;
                    state <= UPDATE;
                end

                UPDATE: begin
                    result_valid <= 1'b0;
                    installed[best_idx] <= 1'b1;
                    install_cnt <= install_cnt + 1;
                    if (ptr < n_pkgs) begin
                        if (valid_pkg[ptr] && !installed[ptr]) begin
                            for (integer k = 0; k < 8; k = k + 1) begin
                                if (k < dep_counts[ptr] && deps[ptr][k] == best_idx) begin
                                    indegree[ptr] <= indegree[ptr] - 1;
                                end
                            end
                        end
                        ptr <= ptr + 1;
                    end else begin
                        ptr <= 0;
                        best_idx <= 3'b111;
                        state <= SEARCH;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                end

                ERROR_STATE: begin
                    error <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule