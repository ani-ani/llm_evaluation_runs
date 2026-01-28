module AppInstaller (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // App count and initial capacity
    input wire [2:0] n,           // Number of apps (1-8)
    input wire [7:0] c,           // Initial disk capacity (0-255)
    
    // App data - 8 apps max, each with 8-bit d and s
    input wire [7:0] d_0, s_0,    // App 1
    input wire [7:0] d_1, s_1,    // App 2
    input wire [7:0] d_2, s_2,    // App 3
    input wire [7:0] d_3, s_3,    // App 4
    input wire [7:0] d_4, s_4,    // App 5
    input wire [7:0] d_5, s_5,    // App 6
    input wire [7:0] d_6, s_6,    // App 7
    input wire [7:0] d_7, s_7,    // App 8
    
    // Outputs
    output reg [2:0] max_count,   // Maximum number of apps that can be installed
    output reg [2:0] order_0,     // App index (0-7) for position 0
    output reg [2:0] order_1,     // App index for position 1
    output reg [2:0] order_2,     // App index for position 2
    output reg [2:0] order_3,     // App index for position 3
    output reg [2:0] order_4,     // App index for position 4
    output reg [2:0] order_5,     // App index for position 5
    output reg [2:0] order_6,     // App index for position 6
    output reg [2:0] order_7,     // App index for position 7
    output reg done               // Computation complete
);

    // Internal state machine states
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] PARTITION   = 4'd1;
    localparam [3:0] SORT_B      = 4'd2;
    localparam [3:0] SORT_A      = 4'd3;
    localparam [3:0] BUILD_ORDER = 4'd4;
    localparam [3:0] SIMULATE    = 4'd5;
    localparam [3:0] FINISH      = 4'd6;
    
    reg [3:0] state, next_state;
    
    // Storage for app data (loaded from inputs)
    reg [7:0] apps_d [0:7];
    reg [7:0] apps_s [0:7];
    reg [7:0] current_capacity;
    
    // Group tracking
    reg [2:0] group_b_count;     // Number of apps in Group B
    reg [2:0] group_a_count;     // Number of apps in Group A
    reg [2:0] temp_order [0:7];  // Temporary order array
    reg [2:0] install_idx;       // Index during simulation
    reg [2:0] idx;               // Current app index
    
    // Sorting variables
    integer i;
    reg [7:0] temp_d, temp_s;
    reg [2:0] temp_idx;
    reg [2:0] num_b_processed;
    reg [2:0] num_a_processed;
    
    // Counter for bubble sort passes
    reg [2:0] sort_pass;
    reg sorting_done;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_count <= 3'd0;
            done <= 1'b0;
            group_b_count <= 3'd0;
            group_a_count <= 3'd0;
            install_idx <= 3'd0;
            current_capacity <= 8'd0;
            num_b_processed <= 3'd0;
            num_a_processed <= 3'd0;
            sort_pass <= 3'd0;
            cycle_count <= 8'd0;
            // Reset order outputs
            order_0 <= 3'd0; order_1 <= 3'd0; order_2 <= 3'd0; order_3 <= 3'd0;
            order_4 <= 3'd0; order_5 <= 3'd0; order_6 <= 3'd0; order_7 <= 3'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PARTITION;
            end
            PARTITION: begin
                next_state = SORT_B;
            end
            SORT_B: begin
                if (num_b_processed >= group_b_count && group_b_count <= 3'd1) begin
                    next_state = SORT_A;
                end else if (sort_pass >= 3'd7) begin
                    next_state = SORT_A;
                end else begin
                    // Check if sorting is done (no swaps in pass)
                    if (sorting_done) begin
                        next_state = SORT_A;
                    end
                end
            end
            SORT_A: begin
                if (num_a_processed >= group_a_count && group_a_count <= 3'd1) begin
                    next_state = BUILD_ORDER;
                end else if (sort_pass >= 3'd7) begin
                    next_state = BUILD_ORDER;
                end else begin
                    if (sorting_done) begin
                        next_state = BUILD_ORDER;
                    end
                end
            end
            BUILD_ORDER: begin
                next_state = SIMULATE;
            end
            SIMULATE: begin
                if (install_idx >= n || current_capacity < 8'hFF || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Handled in state register
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load app data into internal arrays
                        apps_d[0] <= d_0; apps_s[0] <= s_0;
                        apps_d[1] <= d_1; apps_s[1] <= s_1;
                        apps_d[2] <= d_2; apps_s[2] <= s_2;
                        apps_d[3] <= d_3; apps_s[3] <= s_3;
                        apps_d[4] <= d_4; apps_s[4] <= s_4;
                        apps_d[5] <= d_5; apps_s[5] <= s_5;
                        apps_d[6] <= d_6; apps_s[6] <= s_6;
                        apps_d[7] <= d_7; apps_s[7] <= s_7;
                        current_capacity <= c;
                        max_count <= 3'd0;
                        done <= 1'b0;
                        num_b_processed <= 3'd0;
                        num_a_processed <= 3'd0;
                        sort_pass <= 3'd0;
                        cycle_count <= 8'd0;
                    end
                end
                
                PARTITION: begin
                    // Partition into Group A (d <= s) and Group B (d > s)
                    group_b_count <= 3'd0;
                    group_a_count <= 3'd0;
                    // Initialize temp_order with invalid indices (3'b111 = 7)
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_order[i] <= 3'd7; // Mark as empty
                    end
                    
                    // First pass: count and place Group B apps
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n) begin
                            if (apps_d[i] > apps_s[i]) begin
                                if (group_b_count < 8) begin
                                    temp_order[group_b_count] <= i[2:0];
                                    group_b_count <= group_b_count + 3'd1;
                                end
                            end
                        end
                    end
                    
                    // Second pass: place Group A apps
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n) begin
                            if (apps_d[i] <= apps_s[i]) begin
                                if (group_a_count < 8 && (group_b_count + group_a_count) < 8) begin
                                    temp_order[group_b_count + group_a_count] <= i[2:0];
                                    group_a_count <= group_a_count + 3'd1;
                                end
                            end
                        end
                    end
                    
                    num_b_processed <= 3'd0;
                    num_a_processed <= 3'd0;
                    sort_pass <= 3'd0;
                end
                
                SORT_B: begin
                    // Bubble sort on Group B apps by s descending
                    sorting_done <= 1'b1;
                    
                    if (group_b_count > 3'd1 && num_b_processed < group_b_count) begin
                        // Perform one comparison per cycle
                        if (num_b_processed < group_b_count - 3'd1) begin
                            // Compare temp_order[num_b_processed] and temp_order[num_b_processed+1]
                            if (temp_order[num_b_processed] < 3'd7 && temp_order[num_b_processed + 3'd1] < 3'd7) begin
                                if (apps_s[temp_order[num_b_processed]] < apps_s[temp_order[num_b_processed + 3'd1]]) begin
                                    // Swap
                                    temp_idx <= temp_order[num_b_processed];
                                    temp_order[num_b_processed] <= temp_order[num_b_processed + 3'd1];
                                    temp_order[num_b_processed + 3'd1] <= temp_idx;
                                    sorting_done <= 1'b0;
                                end
                            end
                        end
                        num_b_processed <= num_b_processed + 3'd1;
                        sort_pass <= sort_pass + 3'd1;
                    end else begin
                        if (group_b_count > 3'd1) begin
                            num_b_processed <= 3'd0;
                            sort_pass <= sort_pass + 3'd1;
                        end
                    end
                end
                
                SORT_A: begin
                    // Bubble sort on Group A apps by d ascending
                    sorting_done <= 1'b1;
                    
                    if (group_a_count > 3'd1 && num_a_processed < group_a_count) begin
                        // Perform one comparison per cycle
                        if (num_a_processed < group_a_count - 3'd1) begin
                            // Compare temp_order[group_b_count + num_a_processed] and temp_order[group_b_count + num_a_processed + 1]
                            reg [2:0] idx1, idx2;
                            idx1 = group_b_count + num_a_processed;
                            idx2 = group_b_count + num_a_processed + 3'd1;
                            
                            if (temp_order[idx1] < 3'd7 && temp_order[idx2] < 3'd7) begin
                                if (apps_d[temp_order[idx1]] > apps_d[temp_order[idx2]]) begin
                                    temp_idx <= temp_order[idx1];
                                    temp_order[idx1] <= temp_order[idx2];
                                    temp_order[idx2] <= temp_idx;
                                    sorting_done <= 1'b0;
                                end
                            end
                        end
                        num_a_processed <= num_a_processed + 3'd1;
                        sort_pass <= sort_pass + 3'd1;
                    end else begin
                        if (group_a_count > 3'd1) begin
                            num_a_processed <= 3'd0;
                            sort_pass <= sort_pass + 3'd1;
                        end
                    end
                end
                
                BUILD_ORDER: begin
                    // Copy temp_order to output registers
                    order_0 <= temp_order[0];
                    order_1 <= temp_order[1];
                    order_2 <= temp_order[2];
                    order_3 <= temp_order[3];
                    order_4 <= temp_order[4];
                    order_5 <= temp_order[5];
                    order_6 <= temp_order[6];
                    order_7 <= temp_order[7];
                    install_idx <= 3'd0;
                    current_capacity <= c;
                    max_count <= 3'd0;
                    cycle_count <= 8'd0;
                end
                
                SIMULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (install_idx < n && temp_order[install_idx] < 3'd7) begin
                        idx <= temp_order[install_idx];
                        // Check if we can install this app (need max(d, s) <= current capacity)
                        if (current_capacity >= apps_d[install_idx] && current_capacity >= apps_s[install_idx]) begin
                            // Check which is larger: d or s
                            if (apps_d[install_idx] >= apps_s[install_idx]) begin
                                if (current_capacity >= apps_d[install_idx]) begin
                                    // Can install
                                    current_capacity <= current_capacity - apps_d[install_idx];
                                    max_count <= max_count + 3'd1;
                                    install_idx <= install_idx + 3'd1;
                                end else begin
                                    // Cannot install - force exit
                                    install_idx <= n;
                                end
                            end else begin
                                if (current_capacity >= apps_s[install_idx]) begin
                                    // Can install
                                    current_capacity <= current_capacity - apps_s[install_idx];
                                    max_count <= max_count + 3'd1;
                                    install_idx <= install_idx + 3'd1;
                                end else begin
                                    // Cannot install - force exit
                                    install_idx <= n;
                                end
                            end
                        end else begin
                            // Cannot install - force exit
                            install_idx <= n;
                        end
                    end else begin
                        install_idx <= n;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // No additional logic
                end
            endcase
        end
    end
    
endmodule