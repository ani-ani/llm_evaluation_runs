module package_manager (
    input clk,
    input rst_n,
    input start,
    input [2:0] pkg_idx,
    input [79:0] pkg_name,
    input [79:0] dep_name,
    input dep_valid,
    input def_done,
    input [3:0] n_pkgs,
    output reg [79:0] result_name,
    output reg result_valid,
    output reg done,
    output reg error
);

    // States
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] CONFIG = 2'b01;
    localparam [1:0] PROCESS = 2'b10;
    localparam [1:0] DONE = 2'b11;
    reg [1:0] state = IDLE;

    // Package data storage
    reg [79:0] pkg_names [0:7]; // Max 8 packages
    reg [7:0] dep_count [0:7]; // Number of dependencies per package
    reg [79:0] deps [0:7][0:4]; // Max 5 dependencies per package
    reg [7:0] in_degree [0:7]; // Current in-degree for each package
    reg [7:0] installed [0:7]; // 1 if package is installed
    reg [7:0] remaining; // Number of packages remaining to install

    // Configuration phase variables
    reg [2:0] current_pkg_idx = 0;
    reg [7:0] current_dep_idx = 0;

    // Processing phase variables
    reg [2:0] selected_pkg = 0;
    reg [2:0] candidate_pkg = 0;
    reg [7:0] candidate_count = 0;

    // Error detection
    reg cycle_detected = 0;

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_pkg_idx <= 0;
            current_dep_idx <= 0;
            result_valid <= 0;
            done <= 0;
            error <= 0;
            remaining <= 0;
            cycle_detected <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
                pkg_names[i] <= 0;
                dep_count[i] <= 0;
                in_degree[i] <= 0;
                installed[i] <= 0;
                for (int j = 0; j < 5; j = j + 1) begin
                    deps[i][j] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CONFIG;
                        current_pkg_idx <= 0;
                        current_dep_idx <= 0;
                        remaining <= n_pkgs;
                        for (int i = 0; i < 8; i = i + 1) begin
                            pkg_names[i] <= 0;
                            dep_count[i] <= 0;
                            in_degree[i] <= 0;
                            installed[i] <= 0;
                            for (int j = 0; j < 5; j = j + 1) begin
                                deps[i][j] <= 0;
                            end
                        end
                    end
                end
                CONFIG: begin
                    if (def_done) begin
                        current_pkg_idx <= current_pkg_idx + 1;
                        current_dep_idx <= 0;
                        if (current_pkg_idx == n_pkgs) begin
                            state <= PROCESS;
                        end
                    end else if (dep_valid) begin
                        if (current_dep_idx < 5) begin
                            deps[current_pkg_idx][current_dep_idx] <= dep_name;
                            current_dep_idx <= current_dep_idx + 1;
                        end
                    end
                end
                PROCESS: begin
                    if (done) begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    if (start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Configuration phase: store package names and dependencies
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled above
        end else if (state == CONFIG && !def_done && !dep_valid) begin
            pkg_names[pkg_idx] <= pkg_name;
        end
    end

    // After configuration, compute initial in-degrees
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled above
        end else if (state == PROCESS && $past(state) == CONFIG) begin
            // Initialize in_degree based on dependencies
            for (int i = 0; i < 8; i = i + 1) begin
                in_degree[i] <= 0;
                for (int j = 0; j < 8; j = j + 1) begin
                    for (int k = 0; k < 5; k = k + 1) begin
                        if (deps[j][k] == pkg_names[i] && deps[j][k] != 0) begin
                            in_degree[i] <= in_degree[i] + 1;
                        end
                    end
                end
            end
        end
    end

    // Processing phase: find next package to install
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled above
        end else if (state == PROCESS) begin
            candidate_count <= 0;
            selected_pkg <= 0;
            result_valid <= 0;
            error <= 0;
            done <= 0;

            // Find all candidates with in_degree == 0 and not installed
            for (int i = 0; i < 8; i = i + 1) begin
                if (in_degree[i] == 0 && !installed[i] && pkg_names[i] != 0) begin
                    candidate_count <= candidate_count + 1;
                end
            end

            // If no candidates but packages remain, error
            if (candidate_count == 0 && remaining > 0) begin
                cycle_detected <= 1;
                error <= 1;
                done <= 1;
            end
            // If candidates exist, find lex smallest
            else if (candidate_count > 0) begin
                candidate_pkg <= 0;
                for (int i = 0; i < 8; i = i + 1) begin
                    if (in_degree[i] == 0 && !installed[i] && pkg_names[i] != 0) begin
                        if (candidate_pkg == 0 || is_less(pkg_names[i], pkg_names[candidate_pkg])) begin
                            candidate_pkg <= i;
                        end
                    end
                end
                selected_pkg <= candidate_pkg;
                result_name <= pkg_names[selected_pkg];
                result_valid <= 1;
                installed[selected_pkg] <= 1;
                remaining <= remaining - 1;

                // Decrement in_degree of dependents
                for (int j = 0; j < 8; j = j + 1) begin
                    for (int k = 0; k < 5; k = k + 1) begin
                        if (deps[j][k] == pkg_names[selected_pkg] && deps[j][k] != 0) begin
                            in_degree[j] <= in_degree[j] - 1;
                        end
                    end
                end
            end
            // If no packages remain, done
            else if (remaining == 0) begin
                done <= 1;
            end
        end
    end

    // Lexicographical comparison function
    function automatic is_less;
        input [79:0] a, b;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                if (a[8*i +: 8] < b[8*i +: 8]) begin
                    is_less = 1;
                    return;
                end else if (a[8*i +: 8] > b[8*i +: 8]) begin
                    is_less = 0;
                    return;
                end
            end
            is_less = 0; // equal
        end
    endfunction

endmodule