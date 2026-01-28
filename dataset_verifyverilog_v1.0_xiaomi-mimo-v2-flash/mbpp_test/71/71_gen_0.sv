module Combsort(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [3:0] addr_in,
    input load_done,
    output reg [7:0] result,
    output reg [3:0] index,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] SORT       = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] DONE       = 3'd4;
    localparam [2:0] SWAP_WAIT  = 3'd5;

    // Internal memory for array (16x8-bit)
    reg [7:0] memory [0:15];
    integer i;

    // FSM registers
    reg [2:0] state, next_state;
    reg [3:0] array_size;
    reg [3:0] gap;
    reg [3:0] outer_i;
    reg [3:0] inner_i;
    reg [3:0] output_idx;
    reg swapped;
    reg [7:0] temp_val;
    reg [3:0] temp_idx;

    // Cycle counters for timing constraints
    reg [9:0] cycle_count;
    localparam [9:0] MAX_SORT_CYCLES = 10'd1000;
    localparam [9:0] MAX_OUTPUT_CYCLES = 9'd500;
    reg [9:0] output_count;

    // Gap calculation: gap*13/10 (approx 1.3)
    wire [7:0] gap_times_13;
    wire [7:0] gap_div_10;
    assign gap_times_13 = gap * 4'd13;
    assign gap_div_10 = gap_times_13 / 4'd10;

    // Comparator for swap decision
    wire should_swap;
    assign should_swap = (memory[outer_i] > memory[outer_i + gap]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            index <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            output_count <= 10'd0;
            array_size <= 4'd0;
            gap <= 4'd0;
            outer_i <= 4'd0;
            inner_i <= 4'd0;
            output_idx <= 4'd0;
            swapped <= 1'b0;
            temp_val <= 8'd0;
            temp_idx <= 4'd0;
            // Initialize memory to 0
            for (i = 0; i < 16; i = i + 1) begin
                memory[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 10'd0;
                    output_count <= 10'd0;
                    if (load_done) begin
                        array_size <= addr_in;
                        if (start) begin
                            state <= SORT;
                            gap <= addr_in;
                            outer_i <= 4'd0;
                            inner_i <= 4'd0;
                            swapped <= 1'b0;
                            cycle_count <= 10'd1;
                        end else begin
                            state <= LOAD;
                        end
                    end
                end

                LOAD: begin
                    // Continuously load until load_done is asserted
                    // Handled by external controller
                    if (load_done) begin
                        array_size <= addr_in;
                        state <= IDLE;
                    end
                end

                SORT: begin
                    // Prevent infinite loops
                    if (cycle_count >= MAX_SORT_CYCLES) begin
                        state <= OUTPUT;
                        gap <= 4'd0;
                        output_idx <= 4'd0;
                    end else begin
                        cycle_count <= cycle_count + 10'd1;

                        // Outer loop: gap shrink
                        if (gap > 1) begin
                            // Calculate new gap: gap * 13 / 10
                            gap <= (gap * 4'd13) / 4'd10;
                            outer_i <= 4'd0;
                            inner_i <= 4'd0;
                            swapped <= 1'b0;
                            // Continue with inner loop
                        end else if (gap == 1) begin
                            // Inner scan with gap=1
                            if (outer_i < array_size - 1) begin
                                if (should_swap) begin
                                    // Swap elements
                                    temp_val <= memory[outer_i];
                                    memory[outer_i] <= memory[outer_i + 4'd1];
                                    memory[outer_i + 4'd1] <= temp_val;
                                    swapped <= 1'b1;
                                end
                                outer_i <= outer_i + 4'd1;
                            end else begin
                                // Scan complete
                                if (swapped) begin
                                    // Need another pass with gap=1
                                    outer_i <= 4'd0;
                                    swapped <= 1'b0;
                                end else begin
                                    // Sorting complete
                                    state <= OUTPUT;
                                    output_idx <= 4'd0;
                                end
                            end
                        end else begin
                            // gap < 1, should not happen but handle
                            if (swapped) begin
                                gap <= 4'd1;
                                outer_i <= 4'd0;
                                swapped <= 1'b0;
                            end else begin
                                state <= OUTPUT;
                                output_idx <= 4'd0;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    if (output_idx < array_size) begin
                        // Output one element per cycle
                        result <= memory[output_idx];
                        index <= output_idx;
                        valid <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        output_count <= output_count + 10'd1;
                        if (output_idx + 4'd1 >= array_size) begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    // Wait for reset or new load
                    if (load_done) begin
                        state <= LOAD;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Continuous assignment for memory loading in LOAD state
    always @(posedge clk) begin
        if (state == LOAD && load_done == 1'b0) begin
            // When in LOAD state, data_in is captured
            if (addr_in < 16) begin
                memory[addr_in] <= data_in;
            end
        end
    end

endmodule