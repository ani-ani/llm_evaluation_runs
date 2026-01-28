module pizza_solver #(
    parameter NUM_FRIENDS = 4,
    parameter WISHES_PER_FRIEND = 8,
    parameter WISH_WIDTH = 5
)(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_friends,
    input [2:0] num_toppings,
    input [NUM_FRIENDS*WISHES_PER_FRIEND*WISH_WIDTH - 1:0] wishes_packed,
    input [NUM_FRIENDS*3 - 1:0] wishes_count_packed,
    output reg [7:0] subset,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UNPACK = 3'd1;
    localparam [2:0] CHECK_SUBSETS = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Unpacked wishes and counts
    reg [WISH_WIDTH-1:0] wishes [0:NUM_FRIENDS-1][0:WISHES_PER_FRIEND-1];
    reg [2:0] wishes_count [0:NUM_FRIENDS-1];
    
    // Subset checking variables
    reg [7:0] current_subset;
    reg [7:0] subset_counter;
    reg [7:0] friend_counter;
    reg [7:0] wish_counter;
    reg [7:0] satisfied_counter;
    reg [7:0] total_wishes;
    reg [7:0] threshold;
    
    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;
    
    // Unpacking logic
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            subset <= 8'd0;
            current_subset <= 8'd0;
            subset_counter <= 8'd0;
            friend_counter <= 8'd0;
            wish_counter <= 8'd0;
            satisfied_counter <= 8'd0;
            total_wishes <= 8'd0;
            threshold <= 8'd0;
            cycle_count <= 16'd0;
            
            // Initialize unpacked arrays
            for (i = 0; i < NUM_FRIENDS; i = i + 1) begin
                for (j = 0; j < WISHES_PER_FRIEND; j = j + 1) begin
                    wishes[i][j] <= {WISH_WIDTH{1'b0}};
                end
                wishes_count[i] <= 3'd0;
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
                    next_state = UNPACK;
                end
            end
            
            UNPACK: begin
                next_state = CHECK_SUBSETS;
            end
            
            CHECK_SUBSETS: begin
                if (valid || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Unpacking wishes and counts
    always @(posedge clk) begin
        if (state == UNPACK) begin
            for (i = 0; i < NUM_FRIENDS; i = i + 1) begin
                for (j = 0; j < WISHES_PER_FRIEND; j = j + 1) begin
                    wishes[i][j] <= wishes_packed[(i*WISHES_PER_FRIEND + j)*WISH_WIDTH +: WISH_WIDTH];
                end
                wishes_count[i] <= wishes_count_packed[i*3 +: 3];
            end
        end
    end
    
    // Subset checking logic
    always @(posedge clk) begin
        if (state == CHECK_SUBSETS) begin
            cycle_count <= cycle_count + 16'd1;
            
            // Check if current subset is valid
            if (subset_counter == 8'd0) begin
                // Initialize for new subset check
                friend_counter <= 8'd0;
                wish_counter <= 8'd0;
                satisfied_counter <= 8'd0;
                total_wishes <= 8'd0;
                threshold <= 8'd0;
                
                // Calculate total wishes for current friend
                total_wishes <= wishes_count[friend_counter];
                threshold <= (total_wishes * 3'd3) / 3'd10;
                if (threshold == 8'd0) threshold <= 8'd1;
            end
            
            // Check each wish
            if (friend_counter < num_friends && wish_counter < wishes_count[friend_counter]) begin
                // Check if wish is satisfied
                if (wishes[friend_counter][wish_counter][4] && 
                    current_subset[wishes[friend_counter][wish_counter][2:0]]) begin
                    satisfied_counter <= satisfied_counter + 8'd1;
                end
                wish_counter <= wish_counter + 8'd1;
                
                // Move to next friend if done with current
                if (wish_counter >= wishes_count[friend_counter]) begin
                    wish_counter <= 8'd0;
                    friend_counter <= friend_counter + 8'd1;
                end
            end else if (friend_counter == num_friends) begin
                // Check if all friends are satisfied
                if (satisfied_counter >= threshold) begin
                    subset <= current_subset;
                    valid <= 1'b1;
                    done <= 1'b1;
                end
                
                // Move to next subset
                subset_counter <= subset_counter + 8'd1;
                current_subset <= subset_counter;
                friend_counter <= 8'd0;
                wish_counter <= 8'd0;
                satisfied_counter <= 8'd0;
            end
        end
    end
    
    // Reset done and valid when returning to IDLE
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            done <= 1'b1;
        end else if (state == IDLE && start) begin
            done <= 1'b0;
            valid <= 1'b0;
        end
    end

endmodule