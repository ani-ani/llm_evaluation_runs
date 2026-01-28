module PizzaToppingSelection (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire valid,
    input wire data_type,
    input wire [7:0] topping_idx,
    input wire want,
    output reg done,
    output reg [255:0] result
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_COUNTS = 3'd1;
    localparam [2:0] LOAD_WISHES = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    reg [2:0] state, next_state;

    // Memory for friend data
    reg [5:0] friend_satisfied [0:9999];  // 6-bit counter (max 30)
    reg [5:0] friend_total [0:9999];      // 6-bit counter
    reg [15:0] friend_idx;                 // Current friend index (0-9999)
    
    // Topping data
    reg [7:0] topping_count [0:255];      // 8-bit counter for topping popularity
    reg [7:0] current_topping;             // Current topping being processed
    reg [7:0] max_topping;                 // Max toppings (from data)
    reg [5:0] total_wishes;                // Wishes for current friend
    reg [5:0] satisfied_count;             // Satisfied wishes for current friend
    
    // Processing registers
    reg [7:0] topping_idx_reg;             // Store topping index for wish
    reg want_reg;                          // Store want value
    reg [1:0] wish_state;                  // 0=IDLE, 1=GETTING_WISH, 2=EVALUATING
    reg [15:0] process_friend_idx;         // Friend index for processing
    reg [15:0] saved_friend_idx;           // Saved friend index during wish processing
    reg [255:0] selected_toppings;         // Result accumulator
    
    // For computation
    reg [7:0] topping_idx_check;
    reg [5:0] threshold;                   // 1/3 threshold for each friend
    reg friends_satisfied;                 // All friends flag
    reg [15:0] friend_check_idx;           // Friend index for validation
    reg [7:0] cycle_counter;               // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Control signals
    reg [15:0] max_friends;                // Total number of friends
    reg [7:0] current_stage;               // 0=counting, 1=selecting
    reg [7:0] wish_counter;                // Count of wishes read
    reg [7:0] current_wish_idx;            // Current wish in sequence
    
    // Temporary storage
    reg [7:0] temp_topping;
    reg [15:0] temp_friend;
    reg temp_want;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 256'd0;
            selected_toppings <= 256'd0;
            friend_idx <= 16'd0;
            current_topping <= 8'd0;
            max_topping <= 8'd0;
            total_wishes <= 6'd0;
            satisfied_count <= 6'd0;
            wish_state <= 2'd0;
            process_friend_idx <= 16'd0;
            saved_friend_idx <= 16'd0;
            topping_idx_reg <= 8'd0;
            want_reg <= 1'b0;
            topping_idx_check <= 8'd0;
            cycle_counter <= 8'd0;
            current_stage <= 8'd0;
            wish_counter <= 8'd0;
            current_wish_idx <= 8'd0;
            max_friends <= 16'd0;
            
            // Initialize memories
            for (i = 0; i < 10000; i = i + 1) begin
                friend_satisfied[i] <= 6'd0;
                friend_total[i] <= 6'd0;
            end
            for (i = 0; i < 256; i = i + 1) begin
                topping_count[i] <= 8'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    current_stage <= 8'd0;
                    wish_counter <= 8'd0;
                    current_wish_idx <= 8'd0;
                    selected_toppings <= 256'd0;
                    if (start) begin
                        state <= LOAD_COUNTS;
                    end
                end
                
                LOAD_COUNTS: begin
                    if (valid) begin
                        cycle_counter <= cycle_counter + 8'd1;
                        if (cycle_counter >= MAX_CYCLES) begin
                            state <= LOAD_WISHES;
                            cycle_counter <= 8'd0;
                        end else begin
                            if (data_type == 1'b0) begin
                                // New friend: total wishes = topping_idx
                                friend_idx <= friend_idx + 16'd1;
                                max_friends <= friend_idx + 16'd1;
                                total_wishes <= topping_idx[5:0];
                                satisfied_count <= 6'd0;
                            end else begin
                                // Wish: count topping popularity
                                topping_count[topping_idx] <= topping_count[topping_idx] + 8'd1;
                            end
                        end
                    end
                end
                
                LOAD_WISHES: begin
                    if (valid) begin
                        cycle_counter <= cycle_counter + 8'd1;
                        if (cycle_counter >= MAX_CYCLES) begin
                            state <= COMPUTE;
                            cycle_counter <= 8'd0;
                            friend_idx <= 16'd0;
                            current_stage <= 8'd1;
                            selected_toppings <= 256'd0;
                            // Initialize for computation
                            for (i = 0; i < 10000; i = i + 1) begin
                                friend_satisfied[i] <= 6'd0;
                            end
                        end else begin
                            if (data_type == 1'b0) begin
                                // New friend
                                friend_idx <= friend_idx + 16'd1;
                                total_wishes <= topping_idx[5:0];
                                satisfied_count <= 6'd0;
                                wish_counter <= 8'd0;
                                current_wish_idx <= 8'd0;
                            end else begin
                                // Wish - store for later processing
                                if (wish_counter < total_wishes) begin
                                    // Store in memory-like structure
                                    // Use friend_total as temporary storage for wish values
                                    // Since we need to process sequentially, we'll use the next stage
                                    // For now, just count to skip to next friend
                                    wish_counter <= wish_counter + 8'd1;
                                end
                            end
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Two-phase approach: Phase 1 - Estimate, Phase 2 - Refine
                    if (current_stage == 8'd1) begin
                        // Phase 1: Greedy selection based on topping popularity
                        if (cycle_counter < 8'd100) begin
                            // Find next topping to evaluate
                            if (topping_idx_check < 8'd250) begin
                                // Calculate threshold for this topping
                                // Simple heuristic: if popularity > 50% of max, select
                                if (topping_count[topping_idx_check] > 8'd50) begin
                                    selected_toppings[topping_idx_check] <= 1'b1;
                                end
                                topping_idx_check <= topping_idx_check + 8'd1;
                            end else begin
                                // Move to phase 2
                                current_stage <= 8'd2;
                                topping_idx_check <= 8'd0;
                                cycle_counter <= 8'd0;
                            end
                        end
                    end
                    else if (current_stage == 8'd2) begin
                        // Phase 2: Validate and adjust
                        if (cycle_counter < 8'd150) begin
                            // Check each friend's satisfaction
                            if (friend_check_idx < max_friends) begin
                                // Calculate threshold (1/3 of wishes)
                                // Since max wishes = 30, threshold = wishes/3
                                // For simplicity, check if > 10 (which is 1/3 of 30)
                                if (friend_satisfied[friend_check_idx] > 6'd10) begin
                                    // Good enough
                                end else begin
                                    // Need to add more toppings
                                    // Find a topping that helps this friend
                                    if (friend_check_idx < max_friends) begin
                                        // Try to add a topping (simplified)
                                        selected_toppings[friend_check_idx[7:0]] <= 1'b1;
                                    end
                                end
                                friend_check_idx <= friend_check_idx + 16'd1;
                            end else begin
                                // Validation complete
                                state <= OUTPUT;
                                cycle_counter <= 8'd0;
                            end
                        end
                    end
                end
                
                OUTPUT: begin
                    result <= selected_toppings;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Handle wish processing during LOAD_WISHES
            if (state == LOAD_WISHES && valid && data_type == 1'b1) begin
                // Process wish immediately
                if (friend_idx > 16'd0 && friend_idx <= max_friends) begin
                    if (want) begin
                        // Friend wants this topping
                        if (selected_toppings[topping_idx] == 1'b1) begin
                            friend_satisfied[friend_idx - 16'd1] <= friend_satisfied[friend_idx - 16'd1] + 6'd1;
                        end
                    end else begin
                        // Friend doesn't want this topping
                        if (selected_toppings[topping_idx] == 1'b0) begin
                            friend_satisfied[friend_idx - 16'd1] <= friend_satisfied[friend_idx - 16'd1] + 6'd1;
                        end
                    end
                end
            end
        end
    end

endmodule