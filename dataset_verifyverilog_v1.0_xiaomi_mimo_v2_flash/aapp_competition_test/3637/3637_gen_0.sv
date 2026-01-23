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

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] UNPACK      = 3'd1;
    localparam [2:0] CHECK_SUB   = 3'd2;
    localparam [2:0] FOUND       = 3'd3;
    localparam [2:0] NOT_FOUND   = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    reg [2:0] state, next_state;
    
    // Friend data arrays (unpacked for clarity)
    reg [4:0] wishes [0:3][0:7];  // [friend][wish]: {topping[2:0], sign, valid}
    reg [2:0] wish_counts [0:3];  // number of wishes per friend
    
    // Control registers
    reg [7:0] subset_reg;
    reg [2:0] friend_idx;
    reg [2:0] wish_idx;
    reg [2:0] friend_count;
    reg [2:0] topping_count;
    reg found_valid;
    reg [3:0] satisfied_count;
    reg [3:0] total_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    integer i, j, k;
    
    // Helper to check if topping is in subset
    function automatic [0:0] is_topping_in_subset(
        input [7:0] subset_val,
        input [2:0] topping_idx
    );
        is_topping_in_subset = subset_val[topping_idx];
    endfunction
    
    // Helper to count satisfied wishes for one friend
    function automatic [0:0] check_friend(
        input [2:0] num_top,
        input [4:0] wishes_in [0:7],
        input [2:0] wish_cnt,
        input [7:0] subset_val
    );
        reg [3:0] sat;
        reg [3:0] tot;
        reg [2:0] w_top;
        reg w_sign;
        reg w_valid;
        reg [0:0] in_sub;
        begin
            sat = 4'd0;
            tot = 4'd0;
            for (int idx = 0; idx < 8; idx = idx + 1) begin
                if (idx < wish_cnt) begin
                    w_top = wishes_in[idx][4:2];
                    w_sign = wishes_in[idx][1];
                    w_valid = wishes_in[idx][0];
                    if (w_valid && w_top < num_top) begin
                        tot = tot + 4'd1;
                        in_sub = subset_val[w_top];
                        if ((w_sign && in_sub) || (!w_sign && !in_sub)) begin
                            sat = sat + 4'd1;
                        end
                    end
                end
            end
            check_friend = (sat * 3 > tot);
        end
    endfunction
    
    // State transition
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = UNPACK;
            end
            UNPACK: begin
                if (friend_idx >= friend_count) next_state = CHECK_SUB;
            end
            CHECK_SUB: begin
                if (found_valid) next_state = FOUND;
                else if (subset_reg >= 8'd255) next_state = NOT_FOUND;
                else next_state = CHECK_SUB;
            end
            FOUND: next_state = FINISH;
            NOT_FOUND: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset <= 8'd0;
            subset_reg <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            friend_idx <= 3'd0;
            wish_idx <= 3'd0;
            friend_count <= 3'd0;
            topping_count <= 3'd0;
            found_valid <= 1'b0;
            satisfied_count <= 4'd0;
            total_count <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize arrays
            for (i = 0; i < 4; i = i + 1) begin
                wish_counts[i] <= 3'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    wishes[i][j] <= 5'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    subset <= 8'd0;
                    subset_reg <= 8'd0;
                    friend_idx <= 3'd0;
                    wish_idx <= 3'd0;
                    satisfied_count <= 4'd0;
                    total_count <= 4'd0;
                    cycle_count <= 8'd0;
                    found_valid <= 1'b0;
                    friend_count <= num_friends;
                    topping_count <= num_toppings;
                    if (start) begin
                        cycle_count <= 8'd1;
                    end
                end
                
                UNPACK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (friend_idx < 4'd4) begin
                        // Unpack wishes for current friend
                        if (wish_idx < WISHES_PER_FRIEND) begin
                            wishes[friend_idx][wish_idx] <= wishes_packed[
                                (friend_idx * WISHES_PER_FRIEND * WISH_WIDTH) + 
                                (wish_idx * WISH_WIDTH) + WISH_WIDTH - 1 :
                                (friend_idx * WISHES_PER_FRIEND * WISH_WIDTH) + 
                                (wish_idx * WISH_WIDTH)
                            ];
                            wish_idx <= wish_idx + 3'd1;
                        end else begin
                            // Done with current friend's wishes
                            wish_counts[friend_idx] <= wishes_count_packed[
                                (friend_idx * 3) + 2 :
                                (friend_idx * 3)
                            ];
                            friend_idx <= friend_idx + 3'd1;
                            wish_idx <= 3'd0;
                        end
                    end
                end
                
                CHECK_SUB: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check all friends for current subset
                    if (friend_idx < friend_count) begin
                        // Use procedural loop to avoid function call complexity
                        if (wish_idx == 0) begin
                            satisfied_count <= 4'd0;
                            total_count <= 4'd0;
                        end
                        
                        if (wish_idx < wish_counts[friend_idx]) begin
                            // Process one wish
                            if (wishes[friend_idx][wish_idx][0]) begin // valid wish
                                total_count <= total_count + 4'd1;
                                if (is_topping_in_subset(
                                    subset_reg, 
                                    wishes[friend_idx][wish_idx][4:2]
                                )) begin
                                    if (wishes[friend_idx][wish_idx][1]) begin // positive
                                        satisfied_count <= satisfied_count + 4'd1;
                                    end
                                end else begin
                                    if (!wishes[friend_idx][wish_idx][1]) begin // negative
                                        satisfied_count <= satisfied_count + 4'd1;
                                    end
                                end
                            end
                            wish_idx <= wish_idx + 3'd1;
                        end else begin
                            // Done checking this friend
                            if (satisfied_count * 3 > total_count) begin
                                friend_idx <= friend_idx + 3'd1;
                                wish_idx <= 3'd0;
                            end else begin
                                // Friend failed, move to next subset
                                subset_reg <= subset_reg + 8'd1;
                                friend_idx <= 3'd0;
                                wish_idx <= 3'd0;
                            end
                        end
                    end else begin
                        // All friends passed for this subset
                        found_valid <= 1'b1;
                    end
                    
                    // Timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        found_valid <= 1'b0;
                        state <= NOT_FOUND;
                    end
                end
                
                FOUND: begin
                    subset <= subset_reg;
                    valid <= 1'b1;
                    done <= 1'b1;
                end
                
                NOT_FOUND: begin
                    subset <= 8'd0;
                    valid <= 1'b0;
                    done <= 1'b1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule