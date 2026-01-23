module pizza_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_friends,
    input [2:0] num_toppings,
    input [31:0] wishes [0:3],
    output reg found,
    output reg [7:0] selection
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CHECK_SUBSET,
        UPDATE,
        DONE
    } state_t;

    state_t state;
    reg [7:0] subset_counter;
    reg [1:0] friend_counter;
    reg [1:0] wish_counter;
    reg [2:0] satisfied_count;
    reg friend_happy;

    // Reset state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_counter <= 0;
            friend_counter <= 0;
            wish_counter <= 0;
            satisfied_count <= 0;
            friend_happy <= 0;
            found <= 0;
            selection <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK_SUBSET;
                        subset_counter <= 0;
                        friend_counter <= 0;
                        wish_counter <= 0;
                        satisfied_count <= 0;
                        friend_happy <= 0;
                        found <= 0;
                    end
                end
                CHECK_SUBSET: begin
                    if (friend_counter == num_friends) begin
                        state <= UPDATE;
                    end else begin
                        if (wish_counter == 4) begin
                            // Check if friend is happy
                            if (satisfied_count * 3 > 4) begin
                                friend_happy <= 1;
                            end else begin
                                friend_happy <= 0;
                            end
                            friend_counter <= friend_counter + 1;
                            wish_counter <= 0;
                            satisfied_count <= 0;
                        end else begin
                            // Extract wish
                            reg [7:0] wish = wishes[friend_counter][wish_counter * 8 +: 8];
                            reg [2:0] topping_idx = wish[5:3];
                            reg type = wish[2];
                            reg topping_in_subset = subset_counter[topping_idx];

                            // Check if wish is satisfied
                            if ((type && topping_in_subset) || (!type && !topping_in_subset)) begin
                                satisfied_count <= satisfied_count + 1;
                            end
                            wish_counter <= wish_counter + 1;
                        end
                    end
                end
                UPDATE: begin
                    if (friend_happy) begin
                        state <= DONE;
                        found <= 1;
                        selection <= subset_counter;
                    end else begin
                        subset_counter <= subset_counter + 1;
                        friend_counter <= 0;
                        wish_counter <= 0;
                        satisfied_count <= 0;
                        friend_happy <= 0;
                        state <= CHECK_SUBSET;
                    end
                end
                DONE: begin
                    // Stay in DONE state
                end
            endcase
        end
    end

endmodule