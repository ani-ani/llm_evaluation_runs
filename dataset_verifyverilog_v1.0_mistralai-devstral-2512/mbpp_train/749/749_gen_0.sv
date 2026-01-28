module numeric_string_sorter(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input signed [7:0] arr_in [0:15],
    output reg signed [7:0] arr_out [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] SORT = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Internal registers for sorting
    reg signed [7:0] sort_reg [0:15];
    reg [3:0] i_reg, j_reg;
    reg [3:0] outer_loop, inner_loop;
    reg swap_flag;

    // Initialize all registers
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            outer_loop <= 4'd0;
            inner_loop <= 4'd0;
            swap_flag <= 1'b0;
            for (k = 0; k < 16; k = k + 1) begin
                sort_reg[k] <= 8'd0;
                arr_out[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load first 'len' elements from arr_in
                    for (k = 0; k < 16; k = k + 1) begin
                        if (k < len)
                            sort_reg[k] <= arr_in[k];
                        else
                            sort_reg[k] <= 8'd0;
                    end
                    outer_loop <= 4'd0;
                    inner_loop <= 4'd0;
                    next_state <= SORT;
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort implementation
                    if (outer_loop < len - 1) begin
                        if (inner_loop < len - 1 - outer_loop) begin
                            // Compare adjacent elements
                            if (sort_reg[inner_loop] > sort_reg[inner_loop + 1]) begin
                                // Swap
                                sort_reg[inner_loop] <= sort_reg[inner_loop + 1];
                                sort_reg[inner_loop + 1] <= sort_reg[inner_loop];
                                swap_flag <= 1'b1;
                            end
                            inner_loop <= inner_loop + 4'd1;
                        end else begin
                            inner_loop <= 4'd0;
                            outer_loop <= outer_loop + 4'd1;
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Output sorted array
                    for (k = 0; k < 16; k = k + 1) begin
                        arr_out[k] <= sort_reg[k];
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule