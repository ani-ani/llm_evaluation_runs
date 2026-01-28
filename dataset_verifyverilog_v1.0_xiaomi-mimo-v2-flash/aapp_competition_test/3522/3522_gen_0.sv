module BatteryAllocation(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [31:0] batteries[0:31],
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] READ_INPUT    = 4'd1;
    localparam [3:0] SORT          = 4'd2;
    localparam [3:0] BINARY_SEARCH = 4'd3;
    localparam [3:0] ALLOC_CHECK   = 4'd4;
    localparam [3:0] DONE_STATE    = 4'd5;
    
    // Internal registers and wires
    reg [3:0] state, next_state;
    reg [4:0] counter;           // 0-31 for battery index
    reg [4:0] max_count;         // 2*n*k - 1
    reg [31:0] batt_reg[0:31];   // Stored battery values
    reg [31:0] sorted_batt[0:31]; // Sorted batteries
    reg [15:0] d_low, d_high, d_mid; // Binary search bounds
    reg [3:0] iter_counter;      // 0-15 for binary search iterations
    reg [3:0] machine_idx;       // 0-3 for machines
    reg [4:0] batt_idx;          // 0-31 for battery pairing
    reg [15:0] temp_diff;
    reg check_result;
    
    // Sorting network state
    reg [2:0] sort_stage;        // 0-5 for bitonic stages
    reg [4:0] sort_idx;          // Index for sorting comparisons
    reg [4:0] sort_stride;       // Current stride in sorting
    reg [4:0] sort_i, sort_j;    // Indices for comparison
    
    // Max power value (1023 scaled)
    localparam [15:0] MAX_POWER = 16'd1023;
    
    // Cycle counter to prevent infinite loops
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd5000;
    
    // Control signals
    reg start_processing;
    reg sorting_done;
    reg check_valid;
    
    integer i, j;
    
    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 14'd0;
            counter <= 5'd0;
            iter_counter <= 4'd0;
            machine_idx <= 4'd0;
            batt_idx <= 5'd0;
            d_low <= 16'd0;
            d_high <= MAX_POWER;
            d_mid <= 16'd0;
            sort_stage <= 3'd0;
            sort_idx <= 5'd0;
            sort_stride <= 5'd1;
            sorting_done <= 1'b0;
            check_result <= 1'b0;
            start_processing <= 1'b0;
            for (i = 0; i < 32; i = i + 1) begin
                batt_reg[i] <= 32'd0;
                sorted_batt[i] <= 32'd0;
            end
        end else begin
            cycle_count <= cycle_count + 14'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 14'd0;
                    counter <= 5'd0;
                    iter_counter <= 4'd0;
                    sort_stage <= 3'd0;
                    sorting_done <= 1'b0;
                    if (start) begin
                        max_count <= (n * k * 2) - 1;
                        state <= READ_INPUT;
                    end
                end
                
                READ_INPUT: begin
                    if (counter <= max_count) begin
                        batt_reg[counter] <= batteries[counter];
                        sorted_batt[counter] <= batteries[counter];
                        counter <= counter + 5'd1;
                    end else begin
                        counter <= 5'd0;
                        state <= SORT;
                    end
                end
                
                SORT: begin
                    // Bitonic sorting network for up to 32 elements
                    if (!sorting_done) begin
                        case (sort_stage)
                            3'd0: begin // 1-element pairs
                                if (sort_stride <= max_count) begin
                                    for (i = 0; i <= max_count - sort_stride; i = i + sort_stride * 2) begin
                                        if (i + sort_stride <= max_count) begin
                                            if (sorted_batt[i] > sorted_batt[i + sort_stride]) begin
                                                sorted_batt[i] <= sorted_batt[i + sort_stride];
                                                sorted_batt[i + sort_stride] <= sorted_batt[i];
                                            end
                                        end
                                    end
                                    sort_stride <= sort_stride << 1;
                                    if (sort_stride > max_count) begin
                                        sort_stage <= 3'd1;
                                        sort_stride <= 5'd1;
                                    end
                                end
                            end
                            3'd1: begin // 2-element pairs
                                if (sort_stride <= max_count) begin
                                    for (i = 0; i <= max_count - sort_stride; i = i + sort_stride * 2) begin
                                        for (j = 0; j < sort_stride; j = j + 1) begin
                                            if (i + j + sort_stride <= max_count) begin
                                                if (sorted_batt[i + j] > sorted_batt[i + j + sort_stride]) begin
                                                    sorted_batt[i + j] <= sorted_batt[i + j + sort_stride];
                                                    sorted_batt[i + j + sort_stride] <= sorted_batt[i + j];
                                                end
                                            end
                                        end
                                    end
                                    sort_stride <= sort_stride << 1;
                                    if (sort_stride > max_count) begin
                                        sort_stage <= 3'd2;
                                        sort_stride <= 5'd1;
                                    end
                                end
                            end
                            3'd2: begin // 4-element pairs
                                if (sort_stride <= max_count) begin
                                    for (i = 0; i <= max_count - sort_stride; i = i + sort_stride * 2) begin
                                        for (j = 0; j < sort_stride; j = j + 1) begin
                                            if (i + j + sort_stride <= max_count) begin
                                                if (sorted_batt[i + j] > sorted_batt[i + j + sort_stride]) begin
                                                    sorted_batt[i + j] <= sorted_batt[i + j + sort_stride];
                                                    sorted_batt[i + j + sort_stride] <= sorted_batt[i + j];
                                                end
                                            end
                                        end
                                    end
                                    sort_stride <= sort_stride << 1;
                                    if (sort_stride > max_count) begin
                                        sort_stage <= 3'd3;
                                        sort_stride <= 5'd1;
                                    end
                                end
                            end
                            3'd3: begin // 8-element pairs
                                if (sort_stride <= max_count) begin
                                    for (i = 0; i <= max_count - sort_stride; i = i + sort_stride * 2) begin
                                        for (j = 0; j < sort_stride; j = j + 1) begin
                                            if (i + j + sort_stride <= max_count) begin
                                                if (sorted_batt[i + j] > sorted_batt[i + j + sort_stride]) begin
                                                    sorted_batt[i + j] <= sorted_batt[i + j + sort_stride];
                                                    sorted_batt[i + j + sort_stride] <= sorted_batt[i + j];
                                                end
                                            end
                                        end
                                    end
                                    sort_stride <= sort_stride << 1;
                                    if (sort_stride > max_count) begin
                                        sort_stage <= 3'd4;
                                        sort_stride <= 5'd1;
                                    end
                                end
                            end
                            3'd4: begin // 16-element pairs
                                if (sort_stride <= max_count) begin
                                    for (i = 0; i <= max_count - sort_stride; i = i + sort_stride * 2) begin
                                        for (j = 0; j < sort_stride; j = j + 1) begin
                                            if (i + j + sort_stride <= max_count) begin
                                                if (sorted_batt[i + j] > sorted_batt[i + j + sort_stride]) begin
                                                    sorted_batt[i + j] <= sorted_batt[i + j + sort_stride];
                                                    sorted_batt[i + j + sort_stride] <= sorted_batt[i + j];
                                                end
                                            end
                                        end
                                    end
                                    sort_stride <= sort_stride << 1;
                                    if (sort_stride > max_count) begin
                                        sort_stage <= 3'd5;
                                        sort_stride <= 5'd1;
                                    end
                                end
                            end
                            3'd5: begin // 32-element pairs
                                if (sort_stride <= max_count) begin
                                    for (i = 0; i <= max_count - sort_stride; i = i + sort_stride * 2) begin
                                        for (j = 0; j < sort_stride; j = j + 1) begin
                                            if (i + j + sort_stride <= max_count) begin
                                                if (sorted_batt[i + j] > sorted_batt[i + j + sort_stride]) begin
                                                    sorted_batt[i + j] <= sorted_batt[i + j + sort_stride];
                                                    sorted_batt[i + j + sort_stride] <= sorted_batt[i + j];
                                                end
                                            end
                                        end
                                    end
                                    sort_stride <= sort_stride << 1;
                                    if (sort_stride > max_count) begin
                                        sorting_done <= 1'b1;
                                    end
                                end
                            end
                        endcase
                    end
                    
                    if (sorting_done) begin
                        counter <= 5'd0;
                        state <= BINARY_SEARCH;
                    end
                end
                
                BINARY_SEARCH: begin
                    // Binary search for minimal d
                    if (iter_counter < 4'd10) begin
                        d_mid <= (d_low + d_high) >> 1;
                        iter_counter <= iter_counter + 4'd1;
                        state <= ALLOC_CHECK;
                        batt_idx <= 5'd0;
                        machine_idx <= 4'd0;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                ALLOC_CHECK: begin
                    // Check if allocation is possible with current d_mid
                    if (machine_idx < n) begin
                        // Try to find a valid battery pair for this machine
                        if (batt_idx + 1 <= max_count) begin
                            temp_diff <= (sorted_batt[batt_idx + 1] > sorted_batt[batt_idx]) ? 
                                         (sorted_batt[batt_idx + 1] - sorted_batt[batt_idx]) : 
                                         (sorted_batt[batt_idx] - sorted_batt[batt_idx + 1]);
                            
                            if (((sorted_batt[batt_idx + 1] > sorted_batt[batt_idx]) ? 
                                 (sorted_batt[batt_idx + 1] - sorted_batt[batt_idx]) : 
                                 (sorted_batt[batt_idx] - sorted_batt[batt_idx + 1])) <= d_mid) begin
                                // Valid pair found
                                machine_idx <= machine_idx + 4'd1;
                                batt_idx <= batt_idx + 5'd2;
                            end else begin
                                // Try next pair
                                batt_idx <= batt_idx + 5'd1;
                            end
                        end else begin
                            // Not enough batteries for all machines
                            check_result <= 1'b0;
                            state <= BINARY_SEARCH;
                        end
                    end else begin
                        // All machines paired successfully
                        check_result <= 1'b1;
                        state <= BINARY_SEARCH;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    result <= d_low;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Update binary search bounds
            if (state == BINARY_SEARCH && iter_counter > 4'd0 && iter_counter <= 4'd10) begin
                if (check_result) begin
                    d_high <= d_mid;
                end else begin
                    d_low <= d_mid + 16'd1;
                end
            end
            
            // Prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE_STATE;
            end
        end
    end

endmodule