module sort_array(
    input clk,
    input rst_n,
    input start,
    input [7:0] len,
    input [31:0] arr [0:7],
    output reg [31:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] INIT_PASS  = 4'd2;
    localparam [3:0] COMPARE    = 4'd3;
    localparam [3:0] SWAP       = 4'd4;
    localparam [3:0] NEXT_PAIR  = 4'd5;
    localparam [3:0] NEXT_PASS  = 4'd6;
    localparam [3:0] FINISHED   = 4'd7;

    reg [3:0] state, next_state;
    reg [7:0] i_reg, j_reg;
    reg [31:0] temp_reg [0:7];
    reg [31:0] temp_a, temp_b;
    reg [5:0] popcount_a, popcount_b;
    reg [5:0] bit_counter;
    reg [31:0] current_value;
    reg compare_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Popcount computation state
    localparam [1:0] POPCOUNT_IDLE = 2'd0;
    localparam [1:0] POPCOUNT_COMPUTE = 2'd1;
    reg [1:0] popcount_state;
    reg popcount_done;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            popcount_state <= POPCOUNT_IDLE;
            popcount_done <= 1'b0;
            bit_counter <= 6'd0;
            current_value <= 32'd0;
            compare_result <= 1'b0;
            
            // Initialize temp_reg array
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                temp_reg[k] <= 32'd0;
            end
            
            // Initialize result array
            for (k = 0; k < 8; k = k + 1) begin
                result[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    // Copy input array to temp_reg
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        temp_reg[k] <= arr[k];
                    end
                    next_state <= INIT_PASS;
                end

                INIT_PASS: begin
                    i_reg <= 8'd0;
                    j_reg <= 8'd0;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    // Start popcount computation for temp_reg[j_reg] and temp_reg[j_reg + 1]
                    popcount_state <= POPCOUNT_COMPUTE;
                    popcount_done <= 1'b0;
                    bit_counter <= 6'd0;
                    current_value <= temp_reg[j_reg];
                    popcount_a <= 6'd0;
                    next_state <= COMPARE;
                end

                SWAP: begin
                    // Perform swap
                    temp_reg[j_reg] <= temp_b;
                    temp_reg[j_reg + 1] <= temp_a;
                    next_state <= NEXT_PAIR;
                end

                NEXT_PAIR: begin
                    j_reg <= j_reg + 8'd1;
                    if (j_reg < (len - i_reg - 8'd1)) begin
                        next_state <= COMPARE;
                    end else begin
                        next_state <= NEXT_PASS;
                    end
                end

                NEXT_PASS: begin
                    i_reg <= i_reg + 8'd1;
                    if (i_reg < (len - 8'd1)) begin
                        j_reg <= 8'd0;
                        next_state <= COMPARE;
                    end else begin
                        next_state <= FINISHED;
                    end
                end

                FINISHED: begin
                    // Copy temp_reg to result
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        result[k] <= temp_reg[k];
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            
            // Cycle counter for safety
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Popcount computation FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            popcount_state <= POPCOUNT_IDLE;
            popcount_done <= 1'b0;
            bit_counter <= 6'd0;
            current_value <= 32'd0;
            popcount_a <= 6'd0;
            popcount_b <= 6'd0;
        end else begin
            case (popcount_state)
                POPCOUNT_IDLE: begin
                    // Do nothing
                end

                POPCOUNT_COMPUTE: begin
                    if (bit_counter < 6'd32) begin
                        if (current_value[0]) begin
                            if (popcount_a < 6'd32) begin
                                popcount_a <= popcount_a + 6'd1;
                            end
                        end
                        current_value <= current_value >> 1;
                        bit_counter <= bit_counter + 6'd1;
                    end else begin
                        // Done with first popcount, start second
                        popcount_a <= popcount_a;
                        bit_counter <= 6'd0;
                        current_value <= temp_reg[j_reg + 1];
                        popcount_b <= 6'd0;
                        popcount_state <= POPCOUNT_COMPUTE;
                    end
                end

                default: popcount_state <= POPCOUNT_IDLE;
            endcase
            
            // Check if both popcounts are done
            if (popcount_state == POPCOUNT_COMPUTE && bit_counter == 6'd32) begin
                popcount_done <= 1'b1;
                popcount_state <= POPCOUNT_IDLE;
                
                // Compare logic
                if (popcount_a > popcount_b) begin
                    compare_result <= 1'b1;
                end else if (popcount_a == popcount_b) begin
                    if (temp_reg[j_reg] > temp_reg[j_reg + 1]) begin
                        compare_result <= 1'b1;
                    end else begin
                        compare_result <= 1'b0;
                    end
                end else begin
                    compare_result <= 1'b0;
                end
                
                // Store values for potential swap
                temp_a <= temp_reg[j_reg];
                temp_b <= temp_reg[j_reg + 1];
                
                // Transition to SWAP if needed
                if (compare_result) begin
                    next_state <= SWAP;
                end else begin
                    next_state <= NEXT_PAIR;
                end
            end
        end
    end

endmodule