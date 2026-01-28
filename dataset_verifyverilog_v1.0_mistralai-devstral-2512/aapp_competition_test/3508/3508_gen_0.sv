module pillar_collapse(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [3:0] b_addr,
    input wire [23:0] b_data_in,
    input wire b_wr,
    output reg [4:0] max_damage,
    output reg [3:0] best_idx,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOADING = 4'd1;
    localparam [3:0] SCENARIO_LOOP = 4'd2;
    localparam [3:0] SIMULATE_COLLAPSE = 4'd3;
    localparam [3:0] UPDATE_MAX = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // Block RAM for pillar strengths
    reg [23:0] b [0:15];

    // FSM state
    reg [3:0] state, next_state;

    // Scenario loop variables
    reg [3:0] current_pillar;
    reg [3:0] scenario_idx;

    // Collapse simulation variables
    reg [15:0] status;
    reg [15:0] next_status;
    reg [4:0] current_load [0:15];
    reg [3:0] pass_count;
    reg [4:0] damage_count;
    reg [4:0] temp_damage;

    // Load lookup table (pre-calculated values)
    localparam [15:0] LOAD_LUT [0:15] = '{1000, 500, 333, 250, 200, 166, 142, 125, 111, 100, 90, 83, 76, 71, 66, 62};

    // FSM state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            max_damage <= 5'd0;
            best_idx <= 4'd0;
            current_pillar <= 4'd0;
            scenario_idx <= 4'd0;
            pass_count <= 4'd0;
            damage_count <= 5'd0;
            temp_damage <= 5'd0;
            
            // Initialize status and current_load arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                status[i] <= 1'b1;
                next_status[i] <= 1'b1;
                current_load[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOADING;
                end
            end
            
            LOADING: begin
                if (scenario_idx == n - 1) begin
                    next_state = SCENARIO_LOOP;
                end
            end
            
            SCENARIO_LOOP: begin
                if (current_pillar == n - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SIMULATE_COLLAPSE;
                end
            end
            
            SIMULATE_COLLAPSE: begin
                if (pass_count == 4'd15 || !status[15:0]) begin
                    next_state = UPDATE_MAX;
                end
            end
            
            UPDATE_MAX: begin
                next_state = SCENARIO_LOOP;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Block RAM write logic
    always @(posedge clk) begin
        if (b_wr) begin
            b[b_addr] <= b_data_in;
        end
    end

    // Scenario loop logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scenario_idx <= 4'd0;
        end else if (state == LOADING) begin
            if (scenario_idx < n - 1) begin
                scenario_idx <= scenario_idx + 4'd1;
            end
        end
    end

    // Current pillar logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pillar <= 4'd0;
        end else if (state == SCENARIO_LOOP) begin
            if (current_pillar < n - 1) begin
                current_pillar <= current_pillar + 4'd1;
            end
        end else if (state == UPDATE_MAX) begin
            current_pillar <= current_pillar + 4'd1;
        end
    end

    // Pass count logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pass_count <= 4'd0;
        end else if (state == SIMULATE_COLLAPSE) begin
            if (pass_count < 4'd15) begin
                pass_count <= pass_count + 4'd1;
            end
        end else if (state == SCENARIO_LOOP) begin
            pass_count <= 4'd0;
        end
    end

    // Status and load initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                status[i] <= 1'b1;
                next_status[i] <= 1'b1;
                current_load[i] <= 5'd0;
            end
        end else if (state == SCENARIO_LOOP) begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                status[i] <= 1'b1;
                next_status[i] <= 1'b1;
                current_load[i] <= 5'd0;
            end
            // Mark current pillar as destroyed
            status[current_pillar] <= 1'b0;
            next_status[current_pillar] <= 1'b0;
        end
    end

    // Collapse simulation logic
    always @(posedge clk) begin
        if (state == SIMULATE_COLLAPSE) begin
            integer i;
            reg collapse_detected;
            collapse_detected = 1'b0;
            
            // Update loads based on destroyed pillars
            for (i = 0; i < n; i = i + 1) begin
                if (!status[i]) begin
                    integer j;
                    for (j = 0; j < n; j = j + 1) begin
                        if (status[j]) begin
                            reg [3:0] distance;
                            distance = (i > j) ? (i - j) : (j - i);
                            if (distance > 0 && distance < 16) begin
                                current_load[j] <= current_load[j] + LOAD_LUT[distance];
                            end
                        end
                    end
                end
            end
            
            // Check for collapses
            for (i = 0; i < n; i = i + 1) begin
                if (status[i] && current_load[i] > b[i]) begin
                    next_status[i] <= 1'b0;
                    collapse_detected = 1'b1;
                end else begin
                    next_status[i] <= status[i];
                end
            end
            
            // Update status
            for (i = 0; i < 16; i = i + 1) begin
                status[i] <= next_status[i];
            end
            
            // Reset pass count if no collapse detected
            if (!collapse_detected) begin
                pass_count <= 4'd15;
            end
        end
    end

    // Damage count logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_damage <= 5'd0;
        end else if (state == UPDATE_MAX) begin
            integer i;
            temp_damage <= 5'd0;
            for (i = 0; i < n; i = i + 1) begin
                if (!status[i]) begin
                    temp_damage <= temp_damage + 5'd1;
                end
            end
        end
    end

    // Update max damage logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_damage <= 5'd0;
            best_idx <= 4'd0;
        end else if (state == UPDATE_MAX) begin
            if (temp_damage > max_damage) begin
                max_damage <= temp_damage;
                best_idx <= current_pillar;
            end
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule