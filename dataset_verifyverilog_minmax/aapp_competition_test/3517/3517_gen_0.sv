module dp_unit(
    input clk,
    input rst_n,
    input start_scenario,
    input [1:0] node_count,
    input [3:0] deps [0:3],
    input [7:0] time_vals [0:3],
    input zero_en,
    input [1:0] zero_node,
    output reg [7:0] max_path,
    output reg scenario_done
);

    reg idle;
    reg [3:0] processed_mask;
    reg [7:0] longest_path [0:3];
    reg [3:0] cnt;

    wire [3:0] valid_mask;
    wire [3:0] ready;
    wire [1:0] node_idx;
    wire [7:0] dep_max;
    wire [7:0] node_time;
    wire [7:0] new_longest_path [0:3];
    wire [7:0] new_max_path;
    wire [3:0] new_processed_mask;

    // Determine which nodes are valid based on node_count
    always_comb begin
        case (node_count)
            2: valid_mask = 4'b0011;
            3: valid_mask = 4'b0111;
            4: valid_mask = 4'b1111;
            default: valid_mask = 4'b0001;
        endcase
    end

    // Find a ready node (not yet processed, all dependencies satisfied, and valid)
    assign ready = 
        ( (~processed_mask[0] && ((deps[0] & processed_mask) == deps[0]) && valid_mask[0]) ? 4'b0001 :
        ( (~processed_mask[1] && ((deps[1] & processed_mask) == deps[1]) && valid_mask[1]) ? 4'b0010 :
        ( (~processed_mask[2] && ((deps[2] & processed_mask) == deps[2]) && valid_mask[2]) ? 4'b0100 :
        ( (~processed_mask[3] && ((deps[3] & processed_mask) == deps[3]) && valid_mask[3]) ? 4'b1000 :
        4'b0 );

    // Decode ready node index
    assign node_idx = ready[0] ? 2'b00 :
                      ready[1] ? 2'b01 :
                      ready[2] ? 2'b10 :
                      ready[3] ? 2'b11 : 2'b00;

    // Compute max of dependencies for the ready node
    reg [7:0] dep_max_temp;
    always_comb begin
        dep_max_temp = 8'b0;
        if (deps[node_idx][0]) dep_max_temp = (longest_path[0] > dep_max_temp) ? longest_path[0] : dep_max_temp;
        if (deps[node_idx][1]) dep_max_temp = (longest_path[1] > dep_max_temp) ? longest_path[1] : dep_max_temp;
        if (deps[node_idx][2]) dep_max_temp = (longest_path[2] > dep_max_temp) ? longest_path[2] : dep_max_temp;
        if (deps[node_idx][3]) dep_max_temp = (longest_path[3] > dep_max_temp) ? longest_path[3] : dep_max_temp;
        dep_max = dep_max_temp;
    end

    // Node time: zero if this node is the one being eliminated
    assign node_time = (zero_en && zero_node == node_idx && zero_node < node_count) ? 8'b0 : time_vals[node_idx];

    // Update longest_path for the ready node, keep others unchanged
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : NL
            assign new_longest_path[i] = (ready && i == node_idx) ? (dep_max + node_time) : longest_path[i];
        end
    endgenerate

    // Update max_path
    assign new_max_path = (new_longest_path[node_idx] > max_path) ? new_longest_path[node_idx] : max_path;

    // Update processed_mask
    assign new_processed_mask = processed_mask | (1 << node_idx);

    // State machine for a single scenario (10 cycles max)
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            idle <= 1'b1;
            processed_mask <= 4'b0;
            longest_path[0] <= 8'b0;
            longest_path[1] <= 8'b0;
            longest_path[2] <= 8'b0;
            longest_path[3] <= 8'b0;
            max_path <= 8'b0;
            cnt <= 4'b0;
            scenario_done <= 1'b0;
        end else begin
            if (idle) begin
                if (start_scenario) begin
                    idle <= 1'b0;
                    processed_mask <= 4'b0;
                    longest_path[0] <= 8'b0;
                    longest_path[1] <= 8'b0;
                    longest_path[2] <= 8'b0;
                    longest_path[3] <= 8'b0;
                    max_path <= 8'b0;
                    cnt <= 4'b0;
                    scenario_done <= 1'b0;
                end else begin
                    scenario_done <= 1'b0;
                end
            end else begin
                if (cnt < 4'd9) begin
                    processed_mask <= new_processed_mask;
                    longest_path[0] <= new_longest_path[0];
                    longest_path[1] <= new_longest_path[1];
                    longest_path[2] <= new_longest_path[2];
                    longest_path[3] <= new_longest_path[3];
                    max_path <= new_max_path;
                    cnt <= cnt + 1;
                    scenario_done <= 1'b0;
                end else begin
                    scenario_done <= 1'b1;
                    idle <= 1'b1;
                end
            end
        end
    end

endmodule

module critical_path_optimizer(
    input clk,
    input rst_n,
    input start,
    input [1:0] node_count,
    input [7:0] time_vals [0:3],
    input [3:0] deps [0:3],
    output reg [7:0] min_time,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam CALC_BASELINE = 2'b01;
    localparam TRY_ELIM = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [1:0] node_count_reg;
    reg [7:0] time_vals_reg [0:3];
    reg [3:0] deps_reg [0:3];

    reg [7:0] min_time_reg;
    reg dp_start_baseline, dp_start_elim0, dp_start_curr;
    wire dp_done_baseline, dp_done_elim0, dp_done_curr;
    wire [7:0] dp_max_path_baseline, dp_max_path_elim0, dp_max_path_curr;

    reg [3:0] cnt;
    reg [3:0] elim_cnt;
    reg [1:0] elim_idx;
    reg [1:0] zero_node;

    // Instantiate three DP units: baseline (no elimination), elimination of node 0, and current elimination
    dp_unit dp_baseline(
        .clk(clk),
        .rst_n(rst_n),
        .start_scenario(dp_start_baseline),
        .node_count(node_count_reg),
        .deps(deps_reg),
        .time_vals(time_vals_reg),
        .zero_en(1'b0),        // baseline: no zeroing
        .zero_node(2'b00),     // dummy
        .max_path(dp_max_path_baseline),
        .scenario_done(dp_done_baseline)
    );

    dp_unit dp_elim0(
        .clk(clk),
        .rst_n(rst_n),
        .start_scenario(dp_start_elim0),
        .node_count(node_count_reg),
        .deps(deps_reg),
        .time_vals(time_vals_reg),
        .zero_en(1'b1),
        .zero_node(2'b00),     // eliminate node 0
        .max_path(dp_max_path_elim0),
        .scenario_done(dp_done_elim0)
    );

    dp_unit dp_curr(
        .clk(clk),
        .rst_n(rst_n),
        .start_scenario(dp_start_curr),
        .node_count(node_count_reg),
        .deps(deps_reg),
        .time_vals(time_vals_reg),
        .zero_en(1'b1),
        .zero_node(zero_node),
        .max_path(dp_max_path_curr),
        .scenario_done(dp_done_curr)
    );

    // Main state machine
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            dp_start_baseline <= 1'b0;
            dp_start_elim0 <= 1'b0;
            dp_start_curr <= 1'b0;
            cnt <= 4'b0;
            elim_cnt <= 4'b0;
            elim_idx <= 2'b0;
            zero_node <= 2'b0;
            min_time_reg <= 8'hFF;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs
                        node_count_reg <= node_count;
                        time_vals_reg[0] <= time_vals[0];
                        time_vals_reg[1] <= time_vals[1];
                        time_vals_reg[2] <= time_vals[2];
                        time_vals_reg[3] <= time_vals[3];
                        deps_reg[0] <= deps[0];
                        deps_reg[1] <= deps[1];
                        deps_reg[2] <= deps[2];
                        deps_reg[3] <= deps[3];
                        min_time_reg <= 8'hFF;
                        dp_start_baseline <= 1'b1;
                        dp_start_elim0 <= 1'b1;
                        cnt <= 4'b0;
                        state <= CALC_BASELINE;
                    end
                end

                CALC_BASELINE: begin
                    // Deassert start pulses after the first cycle
                    dp_start_baseline <= 1'b0;
                    dp_start_elim0 <= 1'b0;
                    if (cnt < 4'd9) cnt <= cnt + 1;
                    if (dp_done_baseline && dp_done_elim0 && cnt == 4'd9) begin
                        // Compute min from baseline and elimination of node 0
                        min_time_reg <= (dp_max_path_baseline < dp_max_path_elim0) ? dp_max_path_baseline : dp_max_path_elim0;
                        // Start elimination loop from node 1
                        elim_idx <= 2'b1;
                        elim_cnt <= 4'b0;
                        dp_start_curr <= 1'b0;
                        zero_node <= 2'b0;
                        state <= TRY_ELIM;
                    end
                end

                TRY_ELIM: begin
                    if (elim_idx < node_count_reg) begin
                        if (elim_cnt == 4'b0) begin
                            // Start a new elimination scenario
                            zero_node <= elim_idx;
                            dp_start_curr <= 1'b1;
                        end else begin
                            dp_start_curr <= 1'b0;
                        end
                        if (elim_cnt < 4'd9) elim_cnt <= elim_cnt + 1;
                        if (dp_done_curr && elim_cnt == 4'd9) begin
                            // Update min_time with the result of this elimination
                            if (dp_max_path_curr < min_time_reg) min_time_reg <= dp_max_path_curr;
                            // Move to the next elimination
                            elim_idx <= elim_idx + 1;
                            elim_cnt <= 4'b0;
                        end
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Output assignments
    assign min_time = min_time_reg;
    assign done = done;

endmodule