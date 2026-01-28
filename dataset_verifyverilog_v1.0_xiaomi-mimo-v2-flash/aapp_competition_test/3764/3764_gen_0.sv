module RangerProcessor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    input wire [9:0] x_in,
    input wire [7:0][9:0] arr_in,
    output reg [9:0] max_out,
    output reg [9:0] min_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SORTING  = 3'd1;
    localparam [2:0] XORING   = 3'd2;
    localparam [2:0] CHECKING = 3'd3;
    localparam [2:0] FINISHED = 3'd4;
    localparam [2:0] UPDATE   = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] iter_count;
    reg [3:0] sort_count;
    reg [3:0] sort_idx;
    reg [9:0] mem [0:7];
    reg [9:0] temp_max;
    reg [9:0] temp_min;
    reg [2:0] i;
    reg swap_flag;
    reg [9:0] swap_temp;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_out <= 10'd0;
            min_out <= 10'd0;
            done <= 1'b0;
            iter_count <= 4'd0;
            sort_count <= 4'd0;
            sort_idx <= 4'd0;
            temp_max <= 10'd0;
            temp_min <= 10'd0;
            swap_flag <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                mem[i] <= 10'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input array and parameters
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n_in) begin
                                mem[i] <= arr_in[i];
                            end else begin
                                mem[i] <= 10'd0;
                            end
                        end
                        iter_count <= 4'd0;
                        sort_count <= 4'd0;
                        sort_idx <= 4'd0;
                    end
                end
                SORTING: begin
                    // Bubble sort step: compare adjacent elements
                    if (sort_idx < n_in - 1) begin
                        if (mem[sort_idx] > mem[sort_idx + 1]) begin
                            // Swap
                            mem[sort_idx] <= mem[sort_idx + 1];
                            mem[sort_idx + 1] <= mem[sort_idx];
                        end
                        sort_idx <= sort_idx + 4'd1;
                    end else begin
                        // One pass complete
                        sort_idx <= 4'd0;
                        sort_count <= sort_count + 4'd1;
                    end
                end
                XORING: begin
                    // Apply XOR to even indices
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n_in && (i[0] == 1'b0)) begin
                            mem[i] <= mem[i] ^ x_in;
                        end
                    end
                end
                CHECKING: begin
                    // Calculate max/min for this iteration
                    temp_max <= 10'd0;
                    temp_min <= 10'd1023;
                end
                UPDATE: begin
                    // Update max/min from current array
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n_in) begin
                            if (mem[i] > temp_max) temp_max <= mem[i];
                            if (mem[i] < temp_min) temp_min <= mem[i];
                        end
                    end
                end
                FINISHED: begin
                    // Final output
                    max_out <= temp_max;
                    min_out <= temp_min;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (n_in == 4'd0) next_state = FINISHED;
                    else if (k_in == 4'd0) next_state = CHECKING;
                    else next_state = SORTING;
                end else begin
                    next_state = IDLE;
                end
            end
            SORTING: begin
                if (sort_count == 4'd8 || (sort_count >= n_in - 1)) begin
                    next_state = XORING;
                end else begin
                    next_state = SORTING;
                end
            end
            XORING: begin
                next_state = CHECKING;
            end
            CHECKING: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                next_state = CHECKING;
                // Check iteration completion
                if (iter_count == k_in - 1) begin
                    next_state = FINISHED;
                end else begin
                    iter_count = iter_count + 4'd1;
                    next_state = SORTING;
                end
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule