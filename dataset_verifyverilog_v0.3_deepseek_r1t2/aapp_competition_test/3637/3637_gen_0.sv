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
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT          = 3'd1;
    localparam [2:0] CHECK_SUBSET  = 3'd2;
    localparam [2:0] EVALUATE      = 3'd3;
    localparam [2:0] FOUND         = 3'd4;
    localparam [2:0] NOT_FOUND     = 3'd5;
    
    reg [2:0] state, next_state;
    reg [7:0] subset_counter;
    reg [2:0] wishes_count [0:NUM_FRIENDS-1];
    reg [WISH_WIDTH-1:0] wishes [0:NUM_FRIENDS-1][0:WISHES_PER_FRIEND-1];
    integer i, j;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            subset <= 8'd0;
            subset_counter <= 8'd0;
            // Initialize arrays
            for (i = 0; i < NUM_FRIENDS; i = i + 1) begin
                wishes_count[i] <= 3'd0;
                for (j = 0; j < WISHES_PER_FRIEND; j = j + 1) begin
                    wishes[i][j] <= {WISH_WIDTH{1'b0}};
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    subset_counter <= 8'd0;
                    if (start) state <= INIT;
                end
                
                INIT: begin
                    // Unpack wishes_count_packed
                    for (i = 0; i < NUM_FRIENDS; i = i + 1) begin
                        wishes_count[i] = wishes_count_packed[i*3 +: 3];
                        for (j = 0; j < WISHES_PER_FRIEND; j = j + 1) begin
                            wishes[i][j] = wishes_packed[(i*WISHES_PER_FRIEND + j)*WISH_WIDTH +: WISH_WIDTH];
                        end
                    end
                    state <= CHECK_SUBSET;
                end
                
                CHECK_SUBSET: begin
                    reg all_friends_ok;
                    all_friends_ok = 1'b1;
                    
                    for (i = 0; i < NUM_FRIENDS; i = i + 1) begin
                        if (i < num_friends) begin
                            reg [3:0] satisfied;
                            satisfied = 4'd0;
                            for (j = 0; j < WISHES_PER_FRIEND; j = j + 1) begin
                                if (j < wishes_count[i]) begin
                                    reg [2:0] topping_idx;
                                    reg sign, valid_wish;
                                    valid_wish = wishes[i][j][0];
                                    if (valid_wish) begin
                                        topping_idx = wishes[i][j][4:2];
                                        sign = wishes[i][j][1];
                                        if (topping_idx < num_toppings) begin
                                            if ((sign & subset_counter[topping_idx]) | 
                                                (!sign & !subset_counter[topping_idx])) begin
                                                satisfied = satisfied + 4'd1;
                                            end
                                        end
                                    end
                                end
                            end
                            // Check if friend is satisfied (3*satisfied > total_wishes)
                            if (satisfied * 3 <= wishes_count[i]) all_friends_ok = 1'b0;
                        end
                    end
                    
                    if (all_friends_ok) begin
                        state <= FOUND;
                    end else begin
                        subset_counter <= subset_counter + 8'd1;
                        if (subset_counter == 8'd255) state <= NOT_FOUND;
                        else state <= CHECK_SUBSET;
                    end
                end
                
                FOUND: begin
                    subset <= subset_counter;
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                NOT_FOUND: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule