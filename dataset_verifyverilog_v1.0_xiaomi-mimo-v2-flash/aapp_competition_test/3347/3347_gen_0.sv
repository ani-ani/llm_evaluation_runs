module demetrios_gold_scheduling (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] t_i,
    input wire [7:0] h_i,
    input wire [3:0] addr,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_DATA  = 3'd1;
    localparam [2:0] SORT_DATA  = 3'd2;
    localparam [2:0] DP_INIT    = 3'd3;
    localparam [2:0] DP_PROCESS = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers and memory
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Input storage: 16 stores, 16-bit packed {h[7:0], t[7:0]}
    reg [15:0] store_data [0:15];
    reg [3:0] num_stores;
    reg [3:0] idx;
    
    // Sorting registers
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg swap_needed;
    reg [15:0] temp_store;
    
    // DP registers: min_time[c] = min time to visit c stores
    // Max time is 16*255 = 4080, fits in 12 bits
    localparam [11:0] INF = 12'hFFF;
    reg [11:0] min_time [0:16];
    reg [3:0] dp_idx;
    reg [3:0] store_idx;
    reg [11:0] new_time;
    
    // Loop counters
    integer i;
    
    // Cycle counter for timeout protection
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd300;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD_DATA : IDLE;
            LOAD_DATA:  next_state = (idx == n) ? SORT_DATA : LOAD_DATA;
            SORT_DATA:  next_state = (sort_i >= num_stores - 1) ? DP_INIT : SORT_DATA;
            DP_INIT:    next_state = DP_PROCESS;
            DP_PROCESS: next_state = (store_idx >= num_stores) ? FINISH : DP_PROCESS;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // State transition and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 9'd0;
            idx <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            dp_idx <= 4'd0;
            store_idx <= 4'd0;
            new_time <= 12'd0;
            num_stores <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                store_data[i] <= 16'd0;
            end
            for (i = 0; i < 17; i = i + 1) begin
                min_time[i] <= INF;
            end
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 9'd0;
                    idx <= 4'd0;
                    sort_i <= 4'd0;
                    sort_j <= 4'd0;
                    dp_idx <= 4'd0;
                    store_idx <= 4'd0;
                    new_time <= 12'd0;
                    if (start) begin
                        num_stores <= n;
                    end
                end

                LOAD_DATA: begin
                    // Latch store data when addr matches index
                    if (addr == idx) begin
                        store_data[idx] <= {h_i, t_i};
                        idx <= idx + 4'd1;
                    end
                end

                SORT_DATA: begin
                    // Bubble sort by altitude (h_i descending)
                    if (sort_i < num_stores - 1) begin
                        sort_j <= 4'd0;
                        if (sort_j < num_stores - 1 - sort_i) begin
                            // Compare h values: store_data[j][15:8] vs store_data[j+1][15:8]
                            if (store_data[sort_j][15:8] < store_data[sort_j + 1][15:8]) begin
                                // Swap
                                temp_store <= store_data[sort_j];
                                store_data[sort_j] <= store_data[sort_j + 1];
                                store_data[sort_j + 1] <= temp_store;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_i <= sort_i + 4'd1;
                        end
                    end
                end

                DP_INIT: begin
                    // Initialize DP table
                    min_time[0] <= 12'd0;
                    for (i = 1; i < 17; i = i + 1) begin
                        min_time[i] <= INF;
                    end
                    store_idx <= 4'd0;
                end

                DP_PROCESS: begin
                    // Process one store
                    if (store_idx < num_stores) begin
                        // Iterate dp_idx from max down to 0 (for in-place update)
                        // We need to update min_time for all counts
                        for (dp_idx = 16; dp_idx > 0; dp_idx = dp_idx - 1) begin
                            // If we can visit dp_idx stores with some time
                            if (min_time[dp_idx - 1] != INF) begin
                                // Calculate new time: min_time[dp_idx-1] + t_current
                                // t_current is store_data[store_idx][7:0]
                                new_time = min_time[dp_idx - 1] + {4'd0, store_data[store_idx][7:0]};
                                
                                // Check constraint: new_time <= h_current (store_data[store_idx][15:8])
                                if (new_time <= {4'd0, store_data[store_idx][15:8]}) begin
                                    // Update min_time[dp_idx] if new_time is smaller
                                    if (new_time < min_time[dp_idx]) begin
                                        min_time[dp_idx] <= new_time;
                                    end
                                end
                            end
                        end
                        store_idx <= store_idx + 4'd1;
                    end
                end

                FINISH: begin
                    // Find maximum count with valid time
                    result <= 5'd0;
                    for (i = 16; i >= 0; i = i - 1) begin
                        if (min_time[i] != INF && result == 5'd0) begin
                            result <= i[4:0];
                        end
                    end
                    done <= 1'b1;
                end
            endcase
            
            // Cycle count protection
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 9'd1;
            end
            
            // Timeout safety (should not happen with N<=16)
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
            end
        end
    end

endmodule