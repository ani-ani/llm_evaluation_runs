module min_changes_calculator(
    input clk,
    input rst_n,
    input start,
    input row_valid,
    input [15:0] row_data,
    input [3:0] row_len,
    input [3:0] k_max,
    input done_config,
    output reg [3:0] result,
    output reg valid,
    output reg [1:0] status
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOADING = 2'd1;
    localparam [1:0] ENUMERATING = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] row_count;
    reg [15:0] pattern;
    reg [3:0] min_changes;
    reg [3:0] current_cost;
    reg [3:0] row_index;
    reg [3:0] popcount_result;
    reg [3:0] popcount_temp;
    reg [3:0] popcount_cycle;
    reg [3:0] popcount_row_index;
    reg [15:0] popcount_row_data;
    reg [15:0] popcount_pattern;
    reg popcount_valid;

    // Row storage (16x16 bits)
    reg [15:0] row_storage [0:15];

    // Popcount LUT (16-bit input, 5-bit output)
    function [4:0] popcount_lut;
        input [15:0] in;
        integer i;
        begin
            popcount_lut = 0;
            for (i = 0; i < 16; i = i + 1) begin
                if (in[i])
                    popcount_lut = popcount_lut + 1;
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_count <= 4'd0;
            pattern <= 16'd0;
            min_changes <= 4'd16;
            current_cost <= 4'd0;
            row_index <= 4'd0;
            popcount_result <= 4'd0;
            popcount_temp <= 4'd0;
            popcount_cycle <= 4'd0;
            popcount_row_index <= 4'd0;
            popcount_row_data <= 16'd0;
            popcount_pattern <= 16'd0;
            popcount_valid <= 1'b0;
            result <= 4'd0;
            valid <= 1'b0;
            status <= 2'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOADING;
            end
            LOADING: begin
                if (done_config)
                    next_state = ENUMERATING;
            end
            ENUMERATING: begin
                if (pattern == 16'd65535) begin
                    if (min_changes <= k_max)
                        next_state = DONE;
                    else
                        next_state = DONE;
                end
            end
            DONE: begin
                if (start)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Row loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_count <= 4'd0;
        end else begin
            if (state == LOADING && row_valid && row_count < 4'd16) begin
                row_storage[row_count] <= row_data;
                row_count <= row_count + 1'b1;
            end
        end
    end

    // Pattern enumeration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pattern <= 16'd0;
            min_changes <= 4'd16;
            current_cost <= 4'd0;
            row_index <= 4'd0;
        end else begin
            if (state == ENUMERATING) begin
                if (row_index == 4'd0) begin
                    // Start new pattern
                    if (pattern == 16'd65535) begin
                        // All patterns processed
                        if (min_changes <= k_max) begin
                            result <= min_changes;
                            status <= 2'd1;
                        end else begin
                            result <= 4'd15; // -1
                            status <= 2'd2;
                        end
                        valid <= 1'b1;
                    end else begin
                        pattern <= pattern + 1'b1;
                        current_cost <= 4'd0;
                        row_index <= 4'd0;
                    end
                end else begin
                    // Process next row
                    if (popcount_valid) begin
                        // Calculate cost for this row
                        reg [3:0] cost1 = popcount_result;
                        reg [3:0] cost2 = row_len - popcount_result;
                        reg [3:0] min_cost = (cost1 < cost2) ? cost1 : cost2;
                        current_cost <= current_cost + min_cost;
                        
                        // Move to next row
                        row_index <= row_index + 1'b1;
                        
                        // If last row, check if this is a better pattern
                        if (row_index == row_count) begin
                            if (current_cost <= min_changes && current_cost <= k_max) begin
                                min_changes <= current_cost;
                            end
                        end
                        
                        popcount_valid <= 1'b0;
                    end
                end
            end
        end
    end

    // Popcount calculation (pipelined)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            popcount_result <= 4'd0;
            popcount_temp <= 4'd0;
            popcount_cycle <= 4'd0;
            popcount_row_index <= 4'd0;
            popcount_row_data <= 16'd0;
            popcount_pattern <= 16'd0;
            popcount_valid <= 1'b0;
        end else begin
            if (state == ENUMERATING && row_index < row_count && !popcount_valid) begin
                if (popcount_cycle == 4'd0) begin
                    // Start new popcount
                    popcount_row_data <= row_storage[row_index];
                    popcount_pattern <= pattern;
                    popcount_row_index <= row_index;
                    popcount_cycle <= 4'd1;
                end else if (popcount_cycle == 4'd1) begin
                    // Calculate popcount
                    popcount_temp <= popcount_lut(popcount_row_data ^ popcount_pattern);
                    popcount_cycle <= 4'd2;
                end else if (popcount_cycle == 4'd2) begin
                    // Output result
                    popcount_result <= popcount_temp;
                    popcount_valid <= 1'b1;
                    popcount_cycle <= 4'd0;
                end
            end
        end
    end

    // Output control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
        end else begin
            if (state == DONE && start) begin
                valid <= 1'b0;
            end
        end
    end

endmodule