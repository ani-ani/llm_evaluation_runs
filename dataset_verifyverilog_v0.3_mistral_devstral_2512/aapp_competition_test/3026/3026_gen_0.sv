module critical_elements (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [7:0] arr [15:0],
    output reg [7:0] critical [15:0],
    output reg [4:0] critical_count,
    output reg done
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] COMPUTE_ORIG_LIS = 4'd1;
localparam [3:0] WAIT_ORIG_LIS = 4'd2;
localparam [3:0] LOOP_I = 4'd3;
localparam [3:0] BUILD_TEMP_INIT = 4'd4;
localparam [3:0] BUILD_TEMP_LOOP = 4'd5;
localparam [3:0] COMPUTE_TEMP_LIS = 4'd6;
localparam [3:0] WAIT_TEMP_LIS = 4'd7;
localparam [3:0] COMPARE_LIS = 4'd8;
localparam [3:0] INCREMENT_I = 4'd9;
localparam [3:0] SORT_INIT = 4'd10;
localparam [3:0] SORT_PASS_LOOP = 4'd11;
localparam [3:0] SORT_SWAP_LOOP = 4'd12;
localparam [3:0] SORT_NEXT_PASS = 4'd13;
localparam [3:0] OUTPUT_DONE = 4'd14;

// DP FSM states
localparam [2:0] DP_IDLE = 3'd0;
localparam [2:0] DP_INIT = 3'd1;
localparam [2:0] DP_OUTER = 3'd2;
localparam [2:0] DP_INNER = 3'd3;
localparam [2:0] DP_UPDATE = 3'd4;
localparam [2:0] DP_NEXT_J = 3'd5;
localparam [2:0] DP_NEXT_I = 3'd6;
localparam [2:0] DP_FIND_MAX = 3'd7;
localparam [2:0] DP_DONE = 3'd8;

// Registers
reg [3:0] state, next_state;
reg [2:0] dp_state, next_dp_state;
reg [7:0] original_array [15:0];
reg [7:0] temp_array [15:0];
reg [7:0] array_reg [15:0];
reg [4:0] array_len;
reg [4:0] i, j, k;
reg [4:0] pass, idx;
reg [7:0] l_orig, l_temp;
reg [4:0] critical_count_reg;
reg [7:0] critical_array [15:0];
reg start_dp;
reg dp_done;
reg [7:0] lis_result;
reg [4:0] dp_i, dp_j;
reg [7:0] dp_values [15:0];

// Next state logic for main FSM
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = COMPUTE_ORIG_LIS;
        COMPUTE_ORIG_LIS: next_state = WAIT_ORIG_LIS;
        WAIT_ORIG_LIS: if (dp_done) next_state = LOOP_I;
        LOOP_I: if (i < n) next_state = BUILD_TEMP_INIT; else next_state = SORT_INIT;
        BUILD_TEMP_INIT: next_state = BUILD_TEMP_LOOP;
        BUILD_TEMP_LOOP: if (j >= n) next_state = COMPUTE_TEMP_LIS; else next_state = BUILD_TEMP_LOOP;
        COMPUTE_TEMP_LIS: next_state = WAIT_TEMP_LIS;
        WAIT_TEMP_LIS: if (dp_done) next_state = COMPARE_LIS;
        COMPARE_LIS: next_state = INCREMENT_I;
        INCREMENT_I: next_state = LOOP_I;
        SORT_INIT: if (critical_count_reg > 0) next_state = SORT_PASS_LOOP; else next_state = OUTPUT_DONE;
        SORT_PASS_LOOP: if (pass >= critical_count_reg - 1) next_state = OUTPUT_DONE; else next_state = SORT_SWAP_LOOP;
        SORT_SWAP_LOOP: if (idx >= critical_count_reg - 1 - pass) next_state = SORT_NEXT_PASS; else next_state = SORT_SWAP_LOOP;
        SORT_NEXT_PASS: next_state = SORT_PASS_LOOP;
        OUTPUT_DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Next state logic for DP FSM
always @(*) begin
    next_dp_state = dp_state;
    case (dp_state)
        DP_IDLE: if (start_dp) next_dp_state = DP_INIT;
        DP_INIT: next_dp_state = DP_OUTER;
        DP_OUTER: if (dp_i < array_len) next_dp_state = DP_INNER; else next_dp_state = DP_FIND_MAX;
        DP_INNER: if (dp_j < dp_i) next_dp_state = DP_UPDATE; else next_dp_state = DP_NEXT_I;
        DP_UPDATE: next_dp_state = DP_NEXT_J;
        DP_NEXT_J: next_dp_state = DP_INNER;
        DP_NEXT_I: next_dp_state = DP_OUTER;
        DP_FIND_MAX: next_dp_state = DP_DONE;
        DP_DONE: next_dp_state = DP_IDLE;
        default: next_dp_state = DP_IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        dp_state <= DP_IDLE;
        done <= 1'b0;
        critical_count <= 5'd0;
        start_dp <= 1'b0;
        dp_done <= 1'b0;
        i <= 5'd0;
        j <= 5'd0;
        k <= 5'd0;
        pass <= 5'd0;
        idx <= 5'd0;
        l_orig <= 8'd0;
        l_temp <= 8'd0;
        critical_count_reg <= 5'd0;
        dp_i <= 5'd0;
        dp_j <= 5'd0;
        lis_result <= 8'd0;
        
        // Initialize arrays
        integer idx;
        for (idx = 0; idx < 16; idx = idx + 1) begin
            original_array[idx] <= 8'd0;
            temp_array[idx] <= 8'd0;
            array_reg[idx] <= 8'd0;
            critical_array[idx] <= 8'd0;
            dp_values[idx] <= 8'd0;
        end
    end else begin
        state <= next_state;
        dp_state <= next_dp_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Copy input array
                    integer idx;
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        original_array[idx] <= arr[idx];
                    end
                    i <= 5'd0;
                    critical_count_reg <= 5'd0;
                    done <= 1'b0;
                end
            end
            
            COMPUTE_ORIG_LIS: begin
                // Set up for original LIS computation
                integer idx;
                for (idx = 0; idx < 16; idx = idx + 1) begin
                    array_reg[idx] <= original_array[idx];
                end
                array_len <= n;
                start_dp <= 1'b1;
            end
            
            WAIT_ORIG_LIS: begin
                start_dp <= 1'b0;
                if (dp_done) begin
                    l_orig <= lis_result;
                end
            end
            
            LOOP_I: begin
                // No action
            end
            
            BUILD_TEMP_INIT: begin
                j <= 5'd0;
                k <= 5'd0;
            end
            
            BUILD_TEMP_LOOP: begin
                if (j < n) begin
                    if (j != i) begin
                        temp_array[k] <= original_array[j];
                        k <= k + 1;
                    end
                    j <= j + 1;
                end
            end
            
            COMPUTE_TEMP_LIS: begin
                // Set up for temporary LIS computation
                integer idx;
                for (idx = 0; idx < 16; idx = idx + 1) begin
                    array_reg[idx] <= temp_array[idx];
                end
                array_len <= n - 1;
                start_dp <= 1'b1;
            end
            
            WAIT_TEMP_LIS: begin
                start_dp <= 1'b0;
                if (dp_done) begin
                    l_temp <= lis_result;
                end
            end
            
            COMPARE_LIS: begin
                if (l_temp < l_orig) begin
                    critical_array[critical_count_reg] <= original_array[i];
                    critical_count_reg <= critical_count_reg + 1;
                end
            end
            
            INCREMENT_I: begin
                i <= i + 1;
            end
            
            SORT_INIT: begin
                critical_count <= critical_count_reg;
                pass <= 5'd0;
            end
            
            SORT_PASS_LOOP: begin
                if (pass < critical_count_reg - 1) begin
                    idx <= 5'd0;
                end
            end
            
            SORT_SWAP_LOOP: begin
                if (critical_array[idx] > critical_array[idx + 1]) begin
                    // Swap
                    critical_array[idx] <= critical_array[idx + 1];
                    critical_array[idx + 1] <= critical_array[idx];
                end
                idx <= idx + 1;
            end
            
            SORT_NEXT_PASS: begin
                pass <= pass + 1;
            end
            
            OUTPUT_DONE: begin
                done <= 1'b1;
            end
        endcase
        
        // DP FSM actions
        case (dp_state)
            DP_INIT: begin
                integer idx;
                for (idx = 0; idx < 16; idx = idx + 1) begin
                    dp_values[idx] <= 8'd1;
                end
                dp_i <= 5'd0;
            end
            
            DP_OUTER: begin
                if (dp_i < array_len) begin
                    dp_j <= 5'd0;
                end
            end
            
            DP_INNER: begin
                // No action
            end
            
            DP_UPDATE: begin
                if (array_reg[dp_j] < array_reg[dp_i]) begin
                    if (dp_values[dp_j] + 1 > dp_values[dp_i]) begin
                        dp_values[dp_i] <= dp_values[dp_j] + 1;
                    end
                end
            end
            
            DP_NEXT_J: begin
                dp_j <= dp_j + 1;
            end
            
            DP_NEXT_I: begin
                dp_i <= dp_i + 1;
            end
            
            DP_FIND_MAX: begin
                // Find maximum in dp_values
                lis_result <= 8'd0;
                integer idx;
                for (idx = 0; idx < 16; idx = idx + 1) begin
                    if (dp_values[idx] > lis_result) begin
                        lis_result <= dp_values[idx];
                    end
                end
            end
            
            DP_DONE: begin
                dp_done <= 1'b1;
            end
            
            DP_IDLE: begin
                dp_done <= 1'b0;
            end
        endcase
    end
end

endmodule