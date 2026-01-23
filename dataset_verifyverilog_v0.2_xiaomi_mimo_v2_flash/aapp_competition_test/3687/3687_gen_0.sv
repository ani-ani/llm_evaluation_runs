module downlink_verifier(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] q_in,
    input [3:0] s_in,
    input [3:0] sensor_queue_map [3:0],
    input [255:0] queue_capacities [3:0],
    input [255:0] window_downlink [3:0],
    input [255:0] sensor_data [3:0][3:0],
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam READ_PARAMS = 3'b001;
    localparam PROCESS_WINDOW = 3'b010;
    localparam CHECK_RESULT = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] n_reg;
    reg [3:0] q_reg;
    reg [3:0] s_reg;
    reg [255:0] capacities [0:3];
    reg [255:0] downlink [0:3];
    reg [255:0] data [0:3][0:3];
    reg [3:0] sensor_map [0:3];
    
    // Queue levels (fill level)
    reg [255:0] queue_level [0:3];
    
    // Counters and temporary variables
    reg [3:0] window_idx;
    reg [3:0] q_idx;
    reg [3:0] s_idx;
    reg overflow_flag;
    reg all_empty;
    
    // Temporary variables for calculations
    reg [255:0] temp_sum;
    reg [255:0] temp_add;
    reg [255:0] temp_sub;
    reg [255:0] remaining_bw;
    reg [255:0] alloc_amount;
    
    // Helper: check if number is zero (for Q16.16)
    function automatic logic is_zero;
        input [255:0] val;
        integer i;
        begin
            is_zero = 1'b1;
            for (i = 0; i < 256; i = i + 1) begin
                if (val[i]) is_zero = 1'b0;
            end
        end
    endfunction
    
    // Helper: add two Q16.16 numbers
    function automatic [255:0] add_fp;
        input [255:0] a;
        input [255:0] b;
        begin
            add_fp = a + b;
        end
    endfunction
    
    // Helper: subtract two Q16.16 numbers (clamped to zero)
    function automatic [255:0] sub_fp;
        input [255:0] a;
        input [255:0] b;
        begin
            if (a >= b)
                sub_fp = a - b;
            else
                sub_fp = 256'h0;
        end
    endfunction
    
    // Helper: less than or equal
    function automatic logic lte;
        input [255:0] a;
        input [255:0] b;
        integer i;
        begin
            lte = 1'b1;
            for (i = 255; i >= 0; i = i - 1) begin
                if (a[i] && !b[i]) begin
                    lte = 1'b0;
                    disable; // break
                end else if (!a[i] && b[i]) begin
                    lte = 1'b1;
                    disable; // break
                end
            end
        end
    endfunction
    
    // Helper: min function for two values
    function automatic [255:0] min_val;
        input [255:0] a;
        input [255:0] b;
        integer i;
        reg a_gt_b;
        begin
            a_gt_b = 1'b0;
            for (i = 255; i >= 0; i = i - 1) begin
                if (a[i] && !b[i]) begin
                    a_gt_b = 1'b1;
                    disable;
                end else if (!a[i] && b[i]) begin
                    a_gt_b = 1'b0;
                    disable;
                end
            end
            min_val = a_gt_b ? b : a;
        end
    endfunction

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            n_reg <= 4'b0;
            q_reg <= 4'b0;
            s_reg <= 4'b0;
            window_idx <= 4'b0;
            q_idx <= 4'b0;
            s_idx <= 4'b0;
            overflow_flag <= 1'b0;
            // Reset queue levels
            queue_level[0] <= 256'h0;
            queue_level[1] <= 256'h0;
            queue_level[2] <= 256'h0;
            queue_level[3] <= 256'h0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        result <= 1'b0;
                        overflow_flag <= 1'b0;
                        window_idx <= 4'b0;
                        q_idx <= 4'b0;
                        s_idx <= 4'b0;
                        // Reset queue levels
                        queue_level[0] <= 256'h0;
                        queue_level[1] <= 256'h0;
                        queue_level[2] <= 256'h0;
                        queue_level[3] <= 256'h0;
                    end
                end
                
                READ_PARAMS: begin
                    // Load all parameters in one cycle (simplification for state machine)
                    n_reg <= n_in;
                    q_reg <= q_in;
                    s_reg <= s_in;
                    // Load mappings and capacities
                    sensor_map[0] <= sensor_queue_map[0];
                    sensor_map[1] <= sensor_queue_map[1];
                    sensor_map[2] <= sensor_queue_map[2];
                    sensor_map[3] <= sensor_queue_map[3];
                    capacities[0] <= queue_capacities[0];
                    capacities[1] <= queue_capacities[1];
                    capacities[2] <= queue_capacities[2];
                    capacities[3] <= queue_capacities[3];
                    downlink[0] <= window_downlink[0];
                    downlink[1] <= window_downlink[1];
                    downlink[2] <= window_downlink[2];
                    downlink[3] <= window_downlink[3];
                    // Load sensor data
                    data[0][0] <= sensor_data[0][0]; data[0][1] <= sensor_data[0][1]; data[0][2] <= sensor_data[0][2]; data[0][3] <= sensor_data[0][3];
                    data[1][0] <= sensor_data[1][0]; data[1][1] <= sensor_data[1][1]; data[1][2] <= sensor_data[1][2]; data[1][3] <= sensor_data[1][3];
                    data[2][0] <= sensor_data[2][0]; data[2][1] <= sensor_data[2][1]; data[2][2] <= sensor_data[2][2]; data[2][3] <= sensor_data[2][3];
                    data[3][0] <= sensor_data[3][0]; data[3][1] <= sensor_data[3][1]; data[3][2] <= sensor_data[3][2]; data[3][3] <= sensor_data[3][3];
                end
                
                PROCESS_WINDOW: begin
                    // This state handles window processing with multi-cycle logic
                    // We use q_idx and s_idx for iteration
                    
                    if (window_idx < n_reg) begin
                        // Step 1: Add sensor data to queues
                        if (s_idx < s_reg) begin
                            // Add data from sensor s_idx to its queue
                            temp_add <= add_fp(queue_level[sensor_map[s_idx]], data[window_idx][s_idx]);
                            // Check overflow in combinational logic below, update here
                            if (!overflow_flag) begin
                                if (temp_add > capacities[sensor_map[s_idx]]) begin
                                    overflow_flag <= 1'b1;
                                end else begin
                                    queue_level[sensor_map[s_idx]] <= temp_add;
                                end
                            end
                            s_idx <= s_idx + 1;
                        end else if (q_idx < q_reg) begin
                            // Step 2: Allocate downlink bandwidth (greedy, queue by queue)
                            // Calculate total data first (needed for optimization check)
                            // For greedy, we iterate queues and subtract
                            
                            // Check if queue has data
                            if (!is_zero(queue_level[q_idx])) begin
                                // Allocate minimum of remaining BW and queue level
                                // We need to track remaining BW across queues
                                // Simplification: use a temporary register for remaining BW
                                if (q_idx == 0) begin
                                    // Start of allocation, initialize remaining BW
                                    remaining_bw <= downlink[window_idx];
                                end
                                
                                alloc_amount <= min_val(queue_level[q_idx], remaining_bw);
                                queue_level[q_idx] <= sub_fp(queue_level[q_idx], alloc_amount);
                                remaining_bw <= sub_fp(remaining_bw, alloc_amount);
                            end
                            q_idx <= q_idx + 1;
                        end else begin
                            // Done with this window
                            window_idx <= window_idx + 1;
                            q_idx <= 4'b0;
                            s_idx <= 4'b0;
                        end
                    end
                end
                
                CHECK_RESULT: begin
                    // Check if all queues are empty
                    if (q_idx < q_reg) begin
                        if (!is_zero(queue_level[q_idx])) begin
                            all_empty <= 1'b0;
                        end else if (q_idx == q_reg - 1 && all_empty) begin
                            all_empty <= 1'b1;
                        end
                        q_idx <= q_idx + 1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (overflow_flag) begin
                        result <= 1'b0;
                    end else if (all_empty) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = READ_PARAMS;
            end
            
            READ_PARAMS: begin
                next_state = PROCESS_WINDOW;
            end
            
            PROCESS_WINDOW: begin
                if (overflow_flag) begin
                    next_state = DONE;
                end else if (window_idx < n_reg) begin
                    // Stay in this state until all windows processed
                    // Multi-step: add data (s_idx < s_reg), then allocate (q_idx < q_reg)
                    if (s_idx < s_reg) begin
                        next_state = PROCESS_WINDOW;
                    end else if (q_idx < q_reg) begin
                        next_state = PROCESS_WINDOW;
                    end else if (window_idx + 1 < n_reg) begin
                        // Next window
                        next_state = PROCESS_WINDOW;
                    end else begin
                        // All windows done
                        next_state = CHECK_RESULT;
                    end
                end else begin
                    next_state = CHECK_RESULT;
                end
            end
            
            CHECK_RESULT: begin
                if (q_idx >= q_reg) begin
                    next_state = DONE;
                end else begin
                    next_state = CHECK_RESULT;
                end
            end
            
            DONE: begin
                next_state = DONE; // Stay in DONE
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Initialize all_empty flag
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            all_empty <= 1'b1;
        end else if (state == IDLE) begin
            all_empty <= 1'b1;
        end else if (state == CHECK_RESULT && q_idx < q_reg) begin
            // Update all_empty based on queue status
            if (!is_zero(queue_level[q_idx])) begin
                all_empty <= 1'b0;
            end
        end
    end

endmodule
