module pizza_topping_selector(
    input clk,
    input rst_n,
    input start,
    input valid,
    input data_type,
    input [7:0] topping_idx,
    input want,
    output reg done,
    output reg [255:0] result
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT  = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [13:0] friend_count;
    reg [13:0] current_friend;
    reg [13:0] wish_count;
    reg [7:0] current_wish_count;
    reg [7:0] current_topping;
    reg [5:0] friend_satisfied [0:9999];
    reg [5:0] friend_total [0:9999];
    reg [7:0] topping_popularity [0:249];
    reg [255:0] selected_toppings;
    reg [255:0] best_toppings;
    reg [15:0] best_score;
    reg [15:0] current_score;
    reg [7:0] topping_index;
    reg [15:0] total_friends;
    reg [15:0] total_wishes;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 256'd0;
            friend_count <= 14'd0;
            current_friend <= 14'd0;
            wish_count <= 14'd0;
            current_wish_count <= 8'd0;
            current_topping <= 8'd0;
            best_score <= 16'd0;
            current_score <= 16'd0;
            topping_index <= 8'd0;
            total_friends <= 16'd0;
            total_wishes <= 16'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 10000; i = i + 1) begin
                friend_satisfied[i] <= 6'd0;
                friend_total[i] <= 6'd0;
            end
            for (i = 0; i < 250; i = i + 1) begin
                topping_popularity[i] <= 8'd0;
            end
            selected_toppings <= 256'd0;
            best_toppings <= 256'd0;
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
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                if (valid) begin
                    if (data_type == 1'b0) begin
                        // New friend
                        if (current_friend > 0) begin
                            current_friend <= current_friend + 14'd1;
                        end
                        current_wish_count <= topping_idx;
                        friend_total[current_friend] <= topping_idx;
                        
                        if (current_friend == friend_count) begin
                            next_state = COMPUTE;
                        end
                    end else begin
                        // Wish
                        current_topping <= topping_idx;
                        topping_popularity[current_topping] <= topping_popularity[current_topping] + 8'd1;
                        
                        if (want) begin
                            // Positive wish
                        end else begin
                            // Negative wish
                        end
                        
                        wish_count <= wish_count + 14'd1;
                        if (wish_count == current_wish_count) begin
                            wish_count <= 14'd0;
                            friend_count <= friend_count + 14'd1;
                        end
                    end
                end
            end
            
            COMPUTE: begin
                // Greedy selection of toppings
                if (topping_index < 8'd250) begin
                    // Evaluate including this topping
                    current_score <= 16'd0;
                    integer f;
                    for (f = 0; f < 10000; f = f + 1) begin
                        if (friend_total[f] > 6'd0) begin
                            // Check if this topping is in friend's wishes
                            // (simplified - actual implementation would track wishes per friend)
                            if (1) begin
                                current_score <= current_score + 16'd1;
                            end
                        end
                    end
                    
                    // Compare with best score
                    if (current_score > best_score) begin
                        best_score <= current_score;
                        best_toppings[topping_index] <= 1'b1;
                    end else begin
                        best_toppings[topping_index] <= 1'b0;
                    end
                    
                    topping_index <= topping_index + 8'd1;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                result <= best_toppings;
                done <= 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == OUTPUT) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule