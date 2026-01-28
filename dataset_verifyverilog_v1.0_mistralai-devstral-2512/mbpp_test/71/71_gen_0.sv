module comb_sort(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire [3:0] addr_in,
    input wire load_done,
    output reg [7:0] result,
    output reg [3:0] index,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] array_size;
    reg [7:0] memory [0:15];
    reg [3:0] load_addr;
    reg [3:0] gap;
    reg [3:0] i_reg;
    reg [3:0] j_reg;
    reg swap_occurred;
    reg [3:0] output_index;
    reg [7:0] temp_data;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            array_size <= 4'd0;
            load_addr <= 4'd0;
            gap <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            swap_occurred <= 1'b0;
            output_index <= 4'd0;
            result <= 8'd0;
            index <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize memory
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                memory[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (load_done) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    if (addr_in < 16) begin
                        memory[addr_in] <= data_in;
                        array_size <= addr_in + 4'd1;
                    end
                    if (start) begin
                        next_state <= SORT;
                        gap <= array_size;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        swap_occurred <= 1'b0;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Outer loop: gap calculation
                        if (gap > 4'd1) begin
                            // gap = gap / 1.3 (using integer arithmetic)
                            gap <= (gap * 10) / 13;
                            if (gap == 4'd0) begin
                                gap <= 4'd1;
                            end
                            i_reg <= 4'd0;
                            j_reg <= 4'd0;
                            swap_occurred <= 1'b0;
                        end

                        // Inner loop: compare and swap
                        if (i_reg + gap < array_size) begin
                            if (memory[i_reg] > memory[i_reg + gap]) begin
                                // Swap
                                temp_data <= memory[i_reg];
                                memory[i_reg] <= memory[i_reg + gap];
                                memory[i_reg + gap] <= temp_data;
                                swap_occurred <= 1'b1;
                            end
                            i_reg <= i_reg + 4'd1;
                        end else begin
                            i_reg <= 4'd0;
                            if (!swap_occurred && gap == 4'd1) begin
                                next_state <= OUTPUT;
                            end else begin
                                // Continue with next gap
                                gap <= (gap * 10) / 13;
                                if (gap == 4'd0) begin
                                    gap <= 4'd1;
                                end
                                swap_occurred <= 1'b0;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    valid <= 1'b1;
                    result <= memory[output_index];
                    index <= output_index;
                    if (output_index == array_size - 4'd1) begin
                        next_state <= DONE_STATE;
                        done <= 1'b1;
                    end else begin
                        output_index <= output_index + 4'd1;
                    end
                end

                DONE_STATE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    if (!start) begin
                        next_state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule