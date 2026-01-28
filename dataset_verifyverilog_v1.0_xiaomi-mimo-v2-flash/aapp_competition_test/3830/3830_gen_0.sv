module snake_returnable_counter (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [1:0] belt_0,
    input [1:0] belt_1,
    input [1:0] belt_2,
    input [1:0] belt_3,
    input [1:0] belt_4,
    input [1:0] belt_5,
    input [1:0] belt_6,
    input [1:0] belt_7,
    input [1:0] belt_8,
    input [1:0] belt_9,
    input [1:0] belt_10,
    input [1:0] belt_11,
    input [1:0] belt_12,
    input [1:0] belt_13,
    input [1:0] belt_14,
    input [1:0] belt_15,
    output reg [5:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CHECK_ALL_SAME = 3'd1;
    localparam [2:0] CHECK_LOOP     = 3'd2;
    localparam [2:0] FINISH         = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [4:0] counter;          // Stores result during computation
    reg [4:0] index;            // Current room index (0 to n-1)
    reg all_same;               // Flag: 1 if all belts are '>' or all are '<'
    reg all_cw;                 // Flag: 1 if all belts are '>'
    reg all_ccw;                // Flag: 1 if all belts are '<'
    reg [1:0] belt_left;        // Belt (i-1)%n
    reg [1:0] belt_right;       // Belt i
    reg [4:0] n_reg;            // Registered n

    // Combinational helper to get belt value based on index
    function automatic [1:0] get_belt;
        input [4:0] idx;
        begin
            case (idx)
                5'd0:  get_belt = belt_0;
                5'd1:  get_belt = belt_1;
                5'd2:  get_belt = belt_2;
                5'd3:  get_belt = belt_3;
                5'd4:  get_belt = belt_4;
                5'd5:  get_belt = belt_5;
                5'd6:  get_belt = belt_6;
                5'd7:  get_belt = belt_7;
                5'd8:  get_belt = belt_8;
                5'd9:  get_belt = belt_9;
                5'd10: get_belt = belt_10;
                5'd11: get_belt = belt_11;
                5'd12: get_belt = belt_12;
                5'd13: get_belt = belt_13;
                5'd14: get_belt = belt_14;
                5'd15: get_belt = belt_15;
                default: get_belt = 2'd0;
            endcase
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            counter <= 5'd0;
            index <= 5'd0;
            all_same <= 1'b0;
            all_cw <= 1'b0;
            all_ccw <= 1'b0;
            belt_left <= 2'd0;
            belt_right <= 2'd0;
            n_reg <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 6'd0;
                    if (start) begin
                        n_reg <= n;
                        if (n == 5'd0 || n == 5'd1) begin
                            // Handle edge cases (though spec says n >= 2)
                            result <= 6'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Start checking if all belts are same
                            counter <= 5'd0; // Use as index for check
                            all_cw <= 1'b1;
                            all_ccw <= 1'b1;
                            state <= CHECK_ALL_SAME;
                        end
                    end
                end

                CHECK_ALL_SAME: begin
                    // Check belt at current counter index
                    if (counter < n_reg) begin
                        belt_right <= get_belt(counter);
                        
                        // Update flags for next cycle based on current belt
                        // Note: Logic is processed in next cycle or combinational
                        // We will update flags immediately based on current belt
                        if (get_belt(counter) != 2'd0) all_cw <= 1'b0;
                        if (get_belt(counter) != 2'd1) all_ccw <= 1'b0;
                        
                        counter <= counter + 5'd1;
                        state <= CHECK_ALL_SAME;
                    end else begin
                        // Finished checking all belts
                        all_same <= all_cw | all_ccw;
                        
                        if (all_cw | all_ccw) begin
                            // All belts are same direction
                            result <= {1'b0, n_reg}; // n is max 16, fits in 6 bits
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Mixed directions, start checking rooms
                            counter <= 5'd0; // Reset for room counting
                            index <= 5'd0;   // Current room index
                            state <= CHECK_LOOP;
                        end
                    end
                end

                CHECK_LOOP: begin
                    if (index < n_reg) begin
                        // Calculate left belt index: (index - 1) % n
                        // Since index is 0..15 and n is 2..16, we can handle wrap manually
                        // if index == 0, left is n-1, else index-1
                        if (index == 5'd0) begin
                            belt_left <= get_belt(n_reg - 5'd1);
                        end else begin
                            belt_left <= get_belt(index - 5'd1);
                        end
                        
                        // Right belt is simply get_belt(index)
                        belt_right <= get_belt(index);
                        
                        // Move to next room
                        index <= index + 5'd1;
                        state <= CHECK_LOOP;
                    end else begin
                        // Done iterating all rooms
                        result <= {1'b0, counter}; // Counter holds the count
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                // Note: FINISH state is not strictly needed as we transition to IDLE directly
                // But we can add it for clarity if needed. For now, we go to IDLE directly.
                
                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for incrementing counter during CHECK_LOOP
    // This runs in parallel with the state machine to update 'counter' based on previous cycle's belts
    always @(*) begin
        if (state == CHECK_LOOP && !start && index != 5'd0) begin
            // Logic: Room (index-1) is returnable if belt_left or belt_right is '-'
            // belt_left from previous cycle was index-1's left
            // belt_right from previous cycle was index-1's right
            // Wait, let's trace carefully.
            // Cycle T: state=CHECK_LOOP, index=i. We load belts for room i.
            // Cycle T+1: state=CHECK_LOOP, index=i+1. We check belts for room i (loaded at T).
            // So we check the stored belts.
        end
    end

    // Refined counter increment logic
    reg increment_counter;
    always @(*) begin
        increment_counter = 1'b0;
        if (state == CHECK_LOOP) begin
            // We are processing room (index - 1)
            // belt_left and belt_right hold the belts for room (index - 1)
            // (Updated in the previous cycle)
            // If index > 0, we are valid.
            if (index > 5'd0) begin
                if (belt_left == 2'd2 || belt_right == 2'd2) begin
                    increment_counter = 1'b1;
                end
            end
        end
    end

    // Update counter in sequential block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 5'd0;
        end else begin
            if (state == IDLE) begin
                counter <= 5'd0;
            end else if (state == CHECK_LOOP && increment_counter) begin
                counter <= counter + 5'd1;
            end
        end
    end

endmodule