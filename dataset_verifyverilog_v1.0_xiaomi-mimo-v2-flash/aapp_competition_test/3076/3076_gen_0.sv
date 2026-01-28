module knapsack_multi_capacity (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] item_size,
    input wire [15:0] item_value,
    input wire item_valid,
    input wire item_done,
    output wire [1023:0] dp_out,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] WAIT_ITEM    = 3'd1;
    localparam [2:0] COMPUTE_DP   = 3'd2;
    localparam [2:0] UPDATE_BUFFER= 3'd3;
    localparam [2:0] FINALIZE     = 3'd4;
    localparam [2:0] DONE_STATE   = 3'd5;
    localparam [2:0] LOAD_ITEM    = 3'd6;

    reg [2:0] state, next_state;
    
    // Internal registers for DP buffers (64 entries, 16-bit each)
    // current_dp holds DP values for previous items
    reg [15:0] current_dp [0:63];
    // next_dp holds intermediate results during item processing
    reg [15:0] next_dp [0:63];
    // temp_dp holds the max result for current capacity during compute
    reg [15:0] temp_dp;
    
    // Item registers
    reg [7:0] current_item_size;
    reg [15:0] current_item_value;
    
    // Counters and flags
    reg [5:0] item_counter;      // Track number of items processed (0-63)
    reg [5:0] cap_counter;       // Capacity counter (1-64)
    reg [5:0] max_items;         // Total number of items to process
    reg item_valid_reg;
    reg item_done_reg;
    reg start_reg;
    
    // Control signals
    reg compute_done;
    reg update_done;
    reg all_items_loaded;
    
    // Loop counter
    integer i;
    
    // Output assignment: pack current_dp[64]..current_dp[0] into dp_out
    // dp_out[15:0] = current_dp[0] (dp[1])
    // dp_out[1023:1008] = current_dp[63] (dp[64])
    assign dp_out = {
        current_dp[63], current_dp[62], current_dp[61], current_dp[60],
        current_dp[59], current_dp[58], current_dp[57], current_dp[56],
        current_dp[55], current_dp[54], current_dp[53], current_dp[52],
        current_dp[51], current_dp[50], current_dp[49], current_dp[48],
        current_dp[47], current_dp[46], current_dp[45], current_dp[44],
        current_dp[43], current_dp[42], current_dp[41], current_dp[40],
        current_dp[39], current_dp[38], current_dp[37], current_dp[36],
        current_dp[35], current_dp[34], current_dp[33], current_dp[32],
        current_dp[31], current_dp[30], current_dp[29], current_dp[28],
        current_dp[27], current_dp[26], current_dp[25], current_dp[24],
        current_dp[23], current_dp[22], current_dp[21], current_dp[20],
        current_dp[19], current_dp[18], current_dp[17], current_dp[16],
        current_dp[15], current_dp[14], current_dp[13], current_dp[12],
        current_dp[11], current_dp[10], current_dp[9],  current_dp[8],
        current_dp[7],  current_dp[6],  current_dp[5],  current_dp[4],
        current_dp[3],  current_dp[2],  current_dp[1],  current_dp[0]
    };
    
    // Synchronous state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            start_reg <= 1'b0;
            item_valid_reg <= 1'b0;
            item_done_reg <= 1'b0;
            item_counter <= 6'd0;
            cap_counter <= 6'd0;
            current_item_size <= 8'd0;
            current_item_value <= 16'd0;
            max_items <= 6'd0;
            compute_done <= 1'b0;
            update_done <= 1'b0;
            all_items_loaded <= 1'b0;
            temp_dp <= 16'd0;
            
            // Initialize DP arrays to zero
            for (i = 0; i < 64; i = i + 1) begin
                current_dp[i] <= 16'd0;
                next_dp[i] <= 16'd0;
            end
        end else begin
            // Register inputs
            if (start) begin
                start_reg <= 1'b1;
            end
            if (item_valid) begin
                item_valid_reg <= 1'b1;
            end
            if (item_done) begin
                item_done_reg <= 1'b1;
            end
            
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    item_counter <= 6'd0;
                    cap_counter <= 6'd0;
                    max_items <= 6'd0;
                    compute_done <= 1'b0;
                    update_done <= 1'b0;
                    all_items_loaded <= 1'b0;
                    temp_dp <= 16'd0;
                    start_reg <= 1'b0;
                    item_valid_reg <= 1'b0;
                    item_done_reg <= 1'b0;
                    current_item_size <= 8'd0;
                    current_item_value <= 16'd0;
                    
                    // Initialize DP arrays to zero
                    for (i = 0; i < 64; i = i + 1) begin
                        current_dp[i] <= 16'd0;
                        next_dp[i] <= 16'd0;
                    end
                end
                
                WAIT_ITEM: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    if (item_valid_reg) begin
                        item_valid_reg <= 1'b0;
                    end
                    if (item_done_reg) begin
                        item_done_reg <= 1'b0;
                        all_items_loaded <= 1'b1;
                    end
                end
                
                LOAD_ITEM: begin
                    // Load current item into registers
                    current_item_size <= item_size;
                    current_item_value <= item_value;
                    cap_counter <= 6'd1;  // Start capacity from 1
                    compute_done <= 1'b0;
                    
                    // Initialize next_dp with current_dp values
                    for (i = 0; i < 64; i = i + 1) begin
                        next_dp[i] <= current_dp[i];
                    end
                end
                
                COMPUTE_DP: begin
                    // Process one capacity per cycle
                    if (cap_counter <= current_item_size) begin
                        // Capacity < item_size: can't include item
                        // next_dp[cap_counter-1] already holds current_dp[cap_counter-1]
                        temp_dp <= next_dp[cap_counter-1];
                    end else begin
                        // Compute max: current_dp[cap] vs current_dp[cap-size] + value
                        if (current_dp[cap_counter - 1] > (current_dp[cap_counter - current_item_size - 1] + current_item_value)) begin
                            temp_dp <= current_dp[cap_counter - 1];
                        end else begin
                            temp_dp <= current_dp[cap_counter - current_item_size - 1] + current_item_value;
                        end
                    end
                    
                    if (cap_counter == 6'd64) begin
                        compute_done <= 1'b1;
                        cap_counter <= 6'd1;  // Reset for update loop
                    end else begin
                        cap_counter <= cap_counter + 6'd1;
                    end
                end
                
                UPDATE_BUFFER: begin
                    // Store computed temp_dp into next_dp
                    // Note: cap_counter was set in previous state
                    next_dp[cap_counter - 1] <= temp_dp;
                    
                    if (cap_counter == 6'd64) begin
                        update_done <= 1'b1;
                    end else begin
                        cap_counter <= cap_counter + 6'd1;
                        update_done <= 1'b0;
                    end
                end
                
                FINALIZE: begin
                    // Copy next_dp to current_dp
                    for (i = 0; i < 64; i = i + 1) begin
                        current_dp[i] <= next_dp[i];
                    end
                    
                    if (!all_items_loaded && item_counter < 6'd64) begin
                        // More items to process
                        item_counter <= item_counter + 6'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_reg) begin
                    next_state = WAIT_ITEM;
                end else begin
                    next_state = IDLE;
                end
            end
            
            WAIT_ITEM: begin
                if (item_valid_reg) begin
                    next_state = LOAD_ITEM;
                end else if (all_items_loaded && (item_counter == max_items)) begin
                    next_state = FINALIZE;
                end else if (all_items_loaded) begin
                    next_state = FINALIZE;
                end else begin
                    next_state = WAIT_ITEM;
                end
            end
            
            LOAD_ITEM: begin
                next_state = COMPUTE_DP;
            end
            
            COMPUTE_DP: begin
                if (compute_done) begin
                    next_state = UPDATE_BUFFER;
                end else begin
                    next_state = COMPUTE_DP;
                end
            end
            
            UPDATE_BUFFER: begin
                if (update_done) begin
                    next_state = FINALIZE;
                end else begin
                    next_state = UPDATE_BUFFER;
                end
            end
            
            FINALIZE: begin
                if (all_items_loaded && (item_counter >= max_items || item_counter >= 6'd64)) begin
                    next_state = DONE_STATE;
                end else if (item_done_reg) begin
                    next_state = WAIT_ITEM;
                end else begin
                    next_state = WAIT_ITEM;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Track max items when item_done is received
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_items <= 6'd0;
        end else begin
            if (item_done && (state == WAIT_ITEM || state == IDLE)) begin
                max_items <= item_counter + 6'd1;  // Current count + the item being processed
            end
        end
    end

endmodule