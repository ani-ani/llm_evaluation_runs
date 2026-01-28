module sort_array_by_popcount(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT   = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] data_reg [0:7];
    reg [3:0] popcount_reg [0:7];
    reg [7:0] sort_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    // Popcount computation
    integer i, j;
    reg [3:0] temp_popcount;

    // Comparator logic
    reg [3:0] pop_a, pop_b;
    reg [7:0] val_a, val_b;
    reg should_swap;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            sort_counter <= 8'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                data_reg[i] <= 8'd0;
                popcount_reg[i] <= 4'd0;
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Latch input array
                        for (i = 0; i < 8; i = i + 1) begin
                            data_reg[i] <= arr[i];
                        end
                        next_state <= COUNT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNT: begin
                    // Compute popcount for each element
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_popcount = 4'd0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (data_reg[i][j]) begin
                                temp_popcount = temp_popcount + 4'd1;
                            end
                        end
                        popcount_reg[i] <= temp_popcount;
                    end
                    next_state <= SORT;
                    sort_counter <= 8'd0;
                end

                SORT: begin
                    // Perform one pass of bubble sort
                    for (i = 0; i < 7; i = i + 1) begin
                        pop_a = popcount_reg[i];
                        pop_b = popcount_reg[i + 1];
                        val_a = data_reg[i];
                        val_b = data_reg[i + 1];

                        // Compare (popcount, value) pairs
                        should_swap = (pop_a > pop_b) || 
                                     (pop_a == pop_b && val_a > val_b);

                        if (should_swap) begin
                            // Swap data
                            data_reg[i] <= val_b;
                            data_reg[i + 1] <= val_a;
                            // Swap popcounts
                            popcount_reg[i] <= pop_b;
                            popcount_reg[i + 1] <= pop_a;
                        end
                    end

                    sort_counter <= sort_counter + 8'd1;

                    // Check if sorting is complete
                    if (sort_counter >= 8'd7 || cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= SORT;
                    end
                end

                OUTPUT: begin
                    // Drive result ports
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= data_reg[i];
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule